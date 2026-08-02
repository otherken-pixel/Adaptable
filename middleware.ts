/**
 * Edge middleware: when social / iMessage crawlers hit /recipe/:id, serve
 * OG HTML (via internal rewrite to /api/og-recipe) so link previews unfurl.
 * Real browsers fall through to the SPA rewrite in vercel.json.
 */

export const config = {
  matcher: ["/recipe/:path*"],
};

const BOT_UA =
  /bot|crawl|slurp|spider|facebookexternalhit|Facebot|twitterbot|linkedinbot|whatsapp|telegram|discord|applebot|embedly|quora|pinterest|slack|vkShare|W3C_Validator|redditbot|preview|SkypeUriPreview|Google-InspectionTool|bingpreview/i;

export default async function middleware(
  request: Request,
): Promise<Response | void> {
  const ua = request.headers.get("user-agent") || "";
  if (!BOT_UA.test(ua)) {
    // Continue to static/SPA handling.
    return;
  }

  const url = new URL(request.url);
  const parts = url.pathname.split("/").filter(Boolean);
  // /recipe/:id
  if (parts[0] !== "recipe" || !parts[1]) {
    return;
  }

  const id = parts[1];
  // Internal rewrite: fetch OG HTML without a client-visible redirect
  // (some crawlers do not follow redirects when unfurling).
  const dest = new URL(
    `/api/og-recipe?id=${encodeURIComponent(id)}`,
    url.origin,
  );
  return fetch(dest);
}
