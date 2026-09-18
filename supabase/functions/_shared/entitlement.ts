/**
 * Plus vs free daily generate/keep caps.
 * Entitlement is read from plus_entitlements — never from a client isPlus flag.
 */

export const FREE_DAILY_GENERATE_LIMIT = 25;

/** Soft daily cap for in-step adapt (free). Plus is unlimited. */
export const FREE_DAILY_ADAPT_LIMIT = 40;

/** Soft daily cap for fridge photo reads (free). Plus is unlimited. */
export const FREE_DAILY_FRIDGE_LIMIT = 20;

/** Plus product IDs from App Store Connect (same as iOS SubscriptionStore). */
export const PLUS_PRODUCT_IDS = ["adaptable_monthly", "adaptable_annual"] as const;

export type PlusProductId = (typeof PLUS_PRODUCT_IDS)[number];

export function isPlusProductId(id: unknown): id is PlusProductId {
  return typeof id === "string" &&
    (PLUS_PRODUCT_IDS as readonly string[]).includes(id);
}

/** null = unlimited (Plus). Free stays at 25/UTC day. */
export function dailyGenerateLimit(isPlus: boolean): number | null {
  return isPlus ? null : FREE_DAILY_GENERATE_LIMIT;
}

/** null = unlimited (Plus). Free keeps the given soft cap. */
export function dailyActionLimit(
  isPlus: boolean,
  freeLimit: number,
): number | null {
  return isPlus ? null : freeLimit;
}

export function isPlusActive(
  row: { is_plus?: unknown; expires_at?: unknown } | null | undefined,
): boolean {
  if (!row || row.is_plus !== true) return false;
  if (row.expires_at == null || row.expires_at === "") return true;
  const exp = typeof row.expires_at === "number"
    ? row.expires_at
    : Date.parse(String(row.expires_at));
  if (!Number.isFinite(exp)) return true;
  // Apple expiresDate is ms; ISO strings parse as ms.
  const expMs = exp < 1e12 ? exp * 1000 : exp;
  return expMs > Date.now();
}

/** Decode a compact JWS payload without verifying the signature. */
export function decodeJwsPayload(
  jws: unknown,
): Record<string, unknown> | null {
  if (typeof jws !== "string") return null;
  const parts = jws.split(".");
  if (parts.length !== 3 || !parts[1]) return null;
  try {
    const json = atobUrl(parts[1]);
    const parsed = JSON.parse(json);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return null;
    }
    return parsed as Record<string, unknown>;
  } catch {
    return null;
  }
}

function atobUrl(segment: string): string {
  let b64 = segment.replace(/-/g, "+").replace(/_/g, "/");
  while (b64.length % 4) b64 += "=";
  return atob(b64);
}

/**
 * Read the caller's entitlement via their JWT client (RLS: own row only).
 * On read errors, treat as free so a missing table cannot uncap Gemini.
 */
export async function resolveDailyGenerateLimit(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
): Promise<number | null> {
  const { data, error } = await supabase
    .from("plus_entitlements")
    .select("is_plus, expires_at")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) {
    console.error("plus entitlement read failed", error);
    return FREE_DAILY_GENERATE_LIMIT;
  }
  return dailyGenerateLimit(isPlusActive(data));
}

/** Plus after Apple verify (or ops grant). Fail closed on read errors. */
export async function resolveIsPlus(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
): Promise<boolean> {
  return (await resolveDailyGenerateLimit(supabase, userId)) === null;
}

/**
 * Soft daily cap for adapt-step / read-fridge.
 * null = Plus unlimited (same resolveDailyGenerateLimit null path).
 * Entitlement read errors fail closed to the free cap.
 */
export async function resolveDailyActionLimit(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
  freeLimit: number,
): Promise<number | null> {
  return dailyActionLimit(await resolveIsPlus(supabase, userId), freeLimit);
}
