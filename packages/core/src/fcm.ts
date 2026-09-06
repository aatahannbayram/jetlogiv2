import { importPKCS8, SignJWT } from 'jose';

import type { Database } from '@dijigoo/db';

import { latestPushToken } from './courier-notify.js';

export interface FcmAccount {
  projectId: string;
  clientEmail: string;
  privateKey: string;
}

export interface FcmPayload {
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
  collapseKey?: string | null;
}

export interface InboxPushInput {
  courierId: string;
  id: string;
  kind: string;
  title: string;
  body: string;
  subjectId?: string | null;
  route?: string | null;
  collapseKey?: string | null;
}

export function parseFcmAccount(raw: string | undefined, projectId?: string): FcmAccount | null {
  if (!raw?.trim()) return null;
  try {
    const parsed = JSON.parse(raw) as {
      project_id?: string;
      client_email?: string;
      private_key?: string;
    };
    const id = projectId || parsed.project_id;
    if (!id || !parsed.client_email || !parsed.private_key) return null;
    return {
      projectId: id,
      clientEmail: parsed.client_email,
      privateKey: parsed.private_key.replace(/\\n/g, '\n'),
    };
  } catch {
    return null;
  }
}

type FetchFn = typeof fetch;

let cached:
  | { token: string; expiresAt: number; email: string }
  | null = null;

export async function googleFcmAccessToken(
  account: FcmAccount,
  fetchFn: FetchFn = fetch,
): Promise<string> {
  const now = Date.now();
  if (cached && cached.email === account.clientEmail && cached.expiresAt > now + 60_000) {
    return cached.token;
  }

  const key = await importPKCS8(account.privateKey, 'RS256');
  const assertion = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(account.clientEmail)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key);

  const res = await fetchFn('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!res.ok) {
    throw new Error(`FCM oauth ${res.status}`);
  }
  const body = (await res.json()) as { access_token?: string; expires_in?: number };
  if (!body.access_token) throw new Error('FCM oauth token missing');
  cached = {
    token: body.access_token,
    email: account.clientEmail,
    expiresAt: now + (body.expires_in ?? 3600) * 1000,
  };
  return body.access_token;
}

export async function sendFcm(
  account: FcmAccount,
  payload: FcmPayload,
  fetchFn: FetchFn = fetch,
): Promise<void> {
  const access = await googleFcmAccessToken(account, fetchFn);
  const res = await fetchFn(
    `https://fcm.googleapis.com/v1/projects/${account.projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${access}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: payload.token,
          collapse_key: payload.collapseKey ?? undefined,
          notification: { title: payload.title, body: payload.body },
          data: payload.data,
          android: { priority: 'HIGH' },
          apns: {
            headers: { 'apns-priority': '10' },
            payload: { aps: { sound: 'default' } },
          },
        },
      }),
    },
  );
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(`FCM send ${res.status} ${text.slice(0, 160)}`);
  }
}

export function resetFcmTokenCache(): void {
  cached = null;
}

/** Inbox already written. FCM is wake-up only — failure must not roll back the row. */
export async function tryDispatchInboxPush(
  db: Database,
  account: FcmAccount | null,
  input: InboxPushInput,
  fetchFn: FetchFn = fetch,
): Promise<boolean> {
  if (!account) return false;
  const token = await latestPushToken(db, input.courierId);
  if (!token) return false;
  try {
    await sendFcm(
      account,
      {
        token,
        title: input.title,
        body: input.body,
        collapseKey: input.collapseKey,
        data: {
          id: input.id,
          kind: input.kind,
          title: input.title,
          body: input.body,
          ...(input.subjectId ? { taskId: input.subjectId } : {}),
          ...(input.route ? { route: input.route } : {}),
        },
      },
      fetchFn,
    );
    return true;
  } catch {
    return false;
  }
}
