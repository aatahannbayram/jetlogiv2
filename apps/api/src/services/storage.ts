import { HeadObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import type { MediaKind } from '@dijigoo/contracts';

import type { Env } from '../env.js';

export interface PresignInput {
  mediaId: string;
  tenantId: string;
  courierId: string;
  kind: MediaKind;
  contentType: string;
  byteSize: number;
  sha256: string;
  capturedAt: Date;
}

export interface PresignOutput {
  uploadUrl: string;
  headers: Record<string, string>;
  storageKey: string;
  bucket: string;
  expiresAt: Date;
}

const PRESIGN_TTL_SECONDS = 900;

export class StorageService {
  private readonly client: S3Client;

  constructor(private readonly env: Env) {
    this.client = new S3Client({
      endpoint: env.S3_ENDPOINT,
      region: env.S3_REGION,
      forcePathStyle: env.S3_FORCE_PATH_STYLE,
      credentials: {
        accessKeyId: env.S3_ACCESS_KEY_ID,
        secretAccessKey: env.S3_SECRET_ACCESS_KEY,
      },
    });
  }

  /**
   * Shift-open selfies go to their own bucket. Keeping them separate is what
   * lets the retention job expire them on a different schedule from delivery
   * evidence without touching a single object key (docs/04-kvkk.md).
   */
  private bucketFor(kind: MediaKind, stepKey?: string): string {
    if (kind === 'photo' && stepKey === 'shift_start') return this.env.S3_SHIFT_PHOTO_BUCKET;
    return this.env.S3_BUCKET;
  }

  /**
   * Key layout is `tenant/date/courier/mediaId.ext`. Date first inside the
   * tenant so a lifecycle rule can target a prefix, and the media id last so
   * two couriers can never collide.
   */
  private keyFor(input: PresignInput): string {
    const day = input.capturedAt.toISOString().slice(0, 10);
    const ext = EXTENSIONS[input.contentType] ?? 'bin';
    return `${input.tenantId}/${day}/${input.courierId}/${input.mediaId}.${ext}`;
  }

  async presignUpload(input: PresignInput, stepKey?: string): Promise<PresignOutput> {
    const bucket = this.bucketFor(input.kind, stepKey);
    const storageKey = this.keyFor(input);

    const command = new PutObjectCommand({
      Bucket: bucket,
      Key: storageKey,
      ContentType: input.contentType,
      ContentLength: input.byteSize,
      // Storage rejects the upload if the bytes do not match, so a truncated
      // or tampered file never becomes evidence.
      ChecksumSHA256: Buffer.from(input.sha256, 'hex').toString('base64'),
      Metadata: {
        'media-id': input.mediaId,
        'courier-id': input.courierId,
        'captured-at': input.capturedAt.toISOString(),
      },
    });

    const uploadUrl = await getSignedUrl(this.client, command, { expiresIn: PRESIGN_TTL_SECONDS });

    return {
      uploadUrl,
      headers: {
        'Content-Type': input.contentType,
        'Content-Length': String(input.byteSize),
        'x-amz-checksum-sha256': Buffer.from(input.sha256, 'hex').toString('base64'),
      },
      storageKey,
      bucket,
      expiresAt: new Date(Date.now() + PRESIGN_TTL_SECONDS * 1000),
    };
  }

  async objectExists(bucket: string, key: string): Promise<boolean> {
    try {
      await this.client.send(new HeadObjectCommand({ Bucket: bucket, Key: key }));
      return true;
    } catch {
      return false;
    }
  }
}

const EXTENSIONS: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'application/pdf': 'pdf',
  'audio/mp4': 'm4a',
};
