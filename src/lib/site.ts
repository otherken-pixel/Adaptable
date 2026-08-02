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

export function recipeShareURL(recipeId: string): string {
  return `${SITE_URL}/recipe/${recipeId}`;
}
