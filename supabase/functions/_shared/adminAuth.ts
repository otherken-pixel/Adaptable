/** Timing-safe compare for webhook / ops secrets. */
export function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const left = enc.encode(a);
  const right = enc.encode(b);
  const len = Math.max(left.length, right.length);
  let diff = left.length ^ right.length;
  for (let i = 0; i < len; i++) {
    diff |= (left[i] ?? 0) ^ (right[i] ?? 0);
  }
  return diff === 0;
}

export function bearerToken(req: Request): string {
  const raw = req.headers.get("Authorization") ?? "";
  return raw.replace(/^Bearer\s+/i, "").trim();
}

/**
 * True when the caller presents the shared ops/webhook secret.
 * Accepts `x-webhook-secret`, `x-backfill-secret`, or `Authorization: Bearer <secret>`.
 */
export function hasSharedSecret(req: Request, secret: string | undefined): boolean {
  if (!secret) return false;
  const header =
    req.headers.get("x-webhook-secret") ??
    req.headers.get("x-backfill-secret") ??
    "";
  if (header && timingSafeEqual(header, secret)) return true;
  const token = bearerToken(req);
  return token.length > 0 && timingSafeEqual(token, secret);
}

/** True when Authorization is exactly the service-role key (not a user JWT). */
export function hasServiceRole(req: Request, serviceKey: string | undefined): boolean {
  if (!serviceKey) return false;
  const token = bearerToken(req);
  return token.length > 0 && timingSafeEqual(token, serviceKey);
}
