/**
 * One-time preview tokens so `keep: true` cannot publish crafted JSON
 * without a prior generate/surprise call.
 */

const encoder = new TextEncoder();

export function fingerprintRecipe(recipe: unknown): string {
  if (!recipe || typeof recipe !== "object") return "";
  const r = recipe as {
    title?: unknown;
    description?: unknown;
    ingredients?: unknown;
    steps?: unknown;
    source_prompt?: unknown;
  };
  const ingredients = Array.isArray(r.ingredients)
    ? r.ingredients.map((ing) => {
      if (!ing || typeof ing !== "object") return "";
      const row = ing as { item?: unknown; quantity?: unknown; note?: unknown };
      return [
        String(row.item ?? "").trim().toLowerCase(),
        String(row.quantity ?? "").trim().toLowerCase(),
        String(row.note ?? "").trim().toLowerCase(),
      ].join("\t");
    })
    : [];
  const steps = Array.isArray(r.steps)
    ? r.steps.map((step) => {
      if (!step || typeof step !== "object") return "";
      const row = step as { instruction?: unknown };
      return String(row.instruction ?? "").trim().toLowerCase();
    })
    : [];
  return JSON.stringify({
    title: String(r.title ?? "").trim().toLowerCase(),
    description: String(r.description ?? "").trim().toLowerCase(),
    ingredients,
    steps,
    source_prompt: String(r.source_prompt ?? "").trim().toLowerCase(),
  });
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return hex(new Uint8Array(digest));
}

export async function signPreviewToken(
  userId: string,
  recipe: unknown,
  secret: string,
): Promise<string> {
  const payload = `${userId}:${fingerprintRecipe(recipe)}`;
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(payload));
  return `v1.${hex(new Uint8Array(sig))}`;
}

export async function verifyPreviewToken(
  token: string,
  userId: string,
  recipe: unknown,
  secret: string,
): Promise<boolean> {
  if (!token || !secret || !userId) return false;
  const expected = await signPreviewToken(userId, recipe, secret);
  return timingSafeEqual(token, expected);
}

function hex(bytes: Uint8Array): string {
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
