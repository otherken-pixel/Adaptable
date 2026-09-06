/**
 * Public web origin for share links, Universal Links, and OG previews.
 * Prefer custom domain when DNS is live; fall back to Vercel project URL.
 */
export const SITE_URL = (
  (import.meta.env.VITE_SITE_URL as string | undefined) ??
  "https://adaptable-pi.vercel.app"
).replace(/\/$/, "");

/** Hosts that may open the native app via Universal Links. */
export const UNIVERSAL_LINK_HOSTS = [
  "adaptable-pi.vercel.app",
  "adaptable.cooking",
  "www.adaptable.cooking",
];

export const SUPPORT_EMAIL = "support@adaptable.app";
export const PRIVACY_EMAIL = "privacy@adaptable.app";

/** App Store numeric id (Connect → App Information → Apple ID). Empty until live. */
export const APP_STORE_ID = (
  import.meta.env.VITE_APP_STORE_ID as string | undefined
)?.trim() ?? "";

export const APP_STORE_URL = APP_STORE_ID
  ? `https://apps.apple.com/app/id${APP_STORE_ID}`
  : "";

export const PUBLIC_EXACT = [
  "/",
  "/privacy",
  "/support",
  "/terms",
  "/community",
  "/reset-password",
  "/auth",
  "/create",
  "/discover",
  "/cook",
] as const;

/** Marketing / legal pages — no app chrome, public without a session. */
export const SITE_PATHS = [
  "/privacy",
  "/support",
  "/terms",
  "/community",
] as const;

export function isPublicPath(pathname: string): boolean {
  if ((PUBLIC_EXACT as readonly string[]).includes(pathname)) return true;
  return pathname.startsWith("/recipe/") || pathname.startsWith("/cook/");
}

export function isSitePath(pathname: string): boolean {
  return (SITE_PATHS as readonly string[]).includes(pathname);
}

export function recipeShareURL(recipeId: string): string {
  return `${SITE_URL}/recipe/${recipeId}`;
}
