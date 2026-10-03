/** IPv4 exact or CIDR. Bos liste = kontrol yok (yerel). */
export function parseCidrList(raw: string | undefined): string[] {
  if (!raw?.trim()) return [];
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

export function ipv4ToInt(ip: string): number | null {
  const parts = ip.split('.');
  if (parts.length !== 4) return null;
  let n = 0;
  for (const p of parts) {
    const o = Number(p);
    if (!Number.isInteger(o) || o < 0 || o > 255) return null;
    n = (n << 8) + o;
  }
  return n >>> 0;
}

export function ipAllowed(ip: string, allowlist: string[]): boolean {
  if (allowlist.length === 0) return true;
  const candidate = ip.includes(':') && ip.startsWith('::ffff:') ? ip.slice(7) : ip;
  const addr = ipv4ToInt(candidate);
  if (addr == null) return false;
  for (const entry of allowlist) {
    if (!entry.includes('/')) {
      if (candidate === entry) return true;
      continue;
    }
    const [base, bitsRaw] = entry.split('/');
    const bits = Number(bitsRaw);
    const net = ipv4ToInt(base ?? '');
    if (net == null || !Number.isInteger(bits) || bits < 0 || bits > 32) continue;
    const mask = bits === 0 ? 0 : (0xffffffff << (32 - bits)) >>> 0;
    if ((addr & mask) === (net & mask)) return true;
  }
  return false;
}
