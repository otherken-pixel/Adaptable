/** Public web origin used for share links, Universal Links, and OG previews. */
export const SITE_URL = (
  (import.meta.env.VITE_SITE_URL as string | undefined) ??
  "https://adaptable-pi.vercel.app"
).replace(/\/$/, "");

export function recipeShareURL(recipeId: string): string {
  return `${SITE_URL}/recipe/${recipeId}`;
}
