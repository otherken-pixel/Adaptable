/**
 * App Store Server API (StoreKit 2) verification.
 *
 * Ken must set these Supabase secrets (In-App Purchase key, not a
 * client shared secret):
 *   APPLE_IAP_ISSUER_ID
 *   APPLE_IAP_KEY_ID
 *   APPLE_IAP_PRIVATE_KEY   (contents of SubscriptionKey_XXXX.p8)
 *   APPLE_BUNDLE_ID         (optional, default com.adaptable.app)
 *
 * Without those keys this module refuses to grant Plus. A forged client
 * JWS is never enough.
 */

import {
  decodeJwsPayload,
  isPlusProductId,
} from "./entitlement.ts";

const PRODUCTION = "https://api.storekit.itunes.apple.com";
const SANDBOX = "https://api.storekit-sandbox.itunes.apple.com";

export function appleIapConfigured(): boolean {
  return Boolean(
    Deno.env.get("APPLE_IAP_ISSUER_ID")?.trim() &&
      Deno.env.get("APPLE_IAP_KEY_ID")?.trim() &&
      Deno.env.get("APPLE_IAP_PRIVATE_KEY")?.trim(),
  );
}

export interface VerifiedPlusTransaction {
  productId: string;
  originalTransactionId: string;
  transactionId: string;
  expiresAt: string | null;
  environment: string;
  entitled: boolean;
}

export async function verifyPlusTransaction(opts: {
  signedTransactionInfo?: string;
  transactionId?: string;
}): Promise<
  | { ok: true; transaction: VerifiedPlusTransaction }
  | { ok: false; status: number; error: string; code?: string }
> {
  if (!appleIapConfigured()) {
    return {
      ok: false,
      status: 503,
      code: "APPLE_IAP_NOT_CONFIGURED",
      error:
        "Plus cannot be verified yet. Set APPLE_IAP_ISSUER_ID, APPLE_IAP_KEY_ID, and APPLE_IAP_PRIVATE_KEY (App Store Server API In-App Purchase key), then redeploy report-plus-entitlement.",
    };
  }

  let transactionId = typeof opts.transactionId === "string"
    ? opts.transactionId.trim()
    : "";
  if (!transactionId && opts.signedTransactionInfo) {
    const payload = decodeJwsPayload(opts.signedTransactionInfo);
    const fromJws = payload?.transactionId ?? payload?.originalTransactionId;
    if (typeof fromJws === "string") transactionId = fromJws.trim();
  }
  if (!transactionId) {
    return {
      ok: false,
      status: 400,
      error: "A StoreKit transaction id or signedTransactionInfo is required.",
    };
  }

  const fetched = await fetchAppleTransaction(transactionId);
  if (!fetched.ok) return fetched;

  const payload = decodeJwsPayload(fetched.signedTransactionInfo);
  if (!payload) {
    return {
      ok: false,
      status: 502,
      error: "Apple returned a transaction we could not read.",
    };
  }

  const productId = String(payload.productId ?? "");
  const bundleId = String(payload.bundleId ?? "");
  const expectedBundle = Deno.env.get("APPLE_BUNDLE_ID")?.trim() ||
    "com.adaptable.app";
  if (bundleId && bundleId !== expectedBundle) {
    return {
      ok: false,
      status: 403,
      error: "That purchase is not for Adaptable.",
    };
  }
  if (!isPlusProductId(productId)) {
    return {
      ok: false,
      status: 403,
      error: "That product is not Adaptable Plus.",
    };
  }

  const revoked = payload.revocationDate != null && payload.revocationDate !== "";
  const expiresMs = numberish(payload.expiresDate);
  const entitled = !revoked && (expiresMs == null || expiresMs > Date.now());

  return {
    ok: true,
    transaction: {
      productId,
      originalTransactionId: String(
        payload.originalTransactionId ?? transactionId,
      ),
      transactionId: String(payload.transactionId ?? transactionId),
      expiresAt: expiresMs != null ? new Date(expiresMs).toISOString() : null,
      environment: String(payload.environment ?? fetched.environment),
      entitled,
    },
  };
}

function numberish(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const n = Number(value);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

async function fetchAppleTransaction(
  transactionId: string,
): Promise<
  | { ok: true; signedTransactionInfo: string; environment: string }
  | { ok: false; status: number; error: string }
> {
  const jwt = await signAppStoreJwt();
  if (!jwt) {
    return {
      ok: false,
      status: 503,
      error: "Could not sign the App Store Server API token.",
    };
  }

  const headers = { Authorization: `Bearer ${jwt}` };
  const path = `/inApps/v1/transactions/${encodeURIComponent(transactionId)}`;

  let res = await fetch(`${PRODUCTION}${path}`, { headers });
  let environment = "Production";
  if (res.status === 404 || res.status === 401) {
    const sandbox = await fetch(`${SANDBOX}${path}`, { headers });
    if (sandbox.ok || sandbox.status !== 404) {
      res = sandbox;
      environment = "Sandbox";
    }
  }

  if (!res.ok) {
    const detail = (await res.text()).slice(0, 240);
    console.error("Apple Get Transaction Info failed", res.status, detail);
    if (res.status === 404) {
      return {
        ok: false,
        status: 404,
        error: "Apple has no transaction with that id.",
      };
    }
    return {
      ok: false,
      status: 502,
      error: "Apple StoreKit verification failed. Try again in a moment.",
    };
  }

  const json = await res.json();
  const signed = json?.signedTransactionInfo;
  if (typeof signed !== "string") {
    return {
      ok: false,
      status: 502,
      error: "Apple returned an empty transaction.",
    };
  }
  return { ok: true, signedTransactionInfo: signed, environment };
}

async function signAppStoreJwt(): Promise<string | null> {
  const issuer = Deno.env.get("APPLE_IAP_ISSUER_ID")!.trim();
  const keyId = Deno.env.get("APPLE_IAP_KEY_ID")!.trim();
  const pem = Deno.env.get("APPLE_IAP_PRIVATE_KEY")!.trim();
  const bundleId = Deno.env.get("APPLE_BUNDLE_ID")?.trim() ||
    "com.adaptable.app";

  try {
    const now = Math.floor(Date.now() / 1000);
    const header = { alg: "ES256", kid: keyId, typ: "JWT" };
    const payload = {
      iss: issuer,
      iat: now,
      exp: now + 20 * 60,
      aud: "appstoreconnect-v1",
      bid: bundleId,
    };
    const unsigned = `${b64urlJson(header)}.${b64urlJson(payload)}`;
    const key = await importPkcs8(pem);
    const sig = await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      new TextEncoder().encode(unsigned),
    );
    return `${unsigned}.${b64url(new Uint8Array(sig))}`;
  } catch (e) {
    console.error("App Store JWT sign failed", e);
    return null;
  }
}

async function importPkcs8(pem: string): Promise<CryptoKey> {
  const cleaned = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const raw = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    raw,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
}

function b64urlJson(obj: unknown): string {
  return b64url(new TextEncoder().encode(JSON.stringify(obj)));
}

function b64url(bytes: Uint8Array): string {
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}
