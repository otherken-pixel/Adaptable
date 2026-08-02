// Vercel Serverless Function — per-recipe OpenGraph/Twitter meta.
//
// Link-preview crawlers (iMessage, WhatsApp, Slack, Facebook, Twitter…)
// don't run JavaScript, so the SPA's client-rendered <head> is invisible
// to them. `vercel.json` rewrites *only crawler* user-agents hitting
// /recipe/:id here (real users keep the static SPA), and this function
// returns a tiny HTML document whose <head> carries the recipe's title,
// description and — the whole point — the AI dish photo as og:image.
//
// Uses the public anon key + RLS-protected read, exactly like the client.

// Public, RLS-guarded values (already committed in .env.example / xcconfig).
// Prefer runtime env when configured, fall back to the known project.
const SUPABASE_URL =
  process.env.VITE_SUPABASE_URL ??
  process.env.SUPABASE_URL ??
  "https://ypziulvtfsyrwpotlevp.supabase.co";
const SUPABASE_ANON_KEY =
  process.env.VITE_SUPABASE_ANON_KEY ??
  process.env.SUPABASE_ANON_KEY ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlweml1bHZ0ZnN5cndwb3RsZXZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMwNzY4MjYsImV4cCI6MjA5ODY1MjgyNn0.MQ_Cm60vcs46ErhyzBz5WPC69zQLewhS2WmExKjnk5Y";

interface RecipeMeta {
  title: string | null;
  description: string | null;
  emoji: string | null;
  image_url: string | null;
  cuisine: string | null;
  difficulty: string | null;
  prep_time_minutes: number | null;
  cook_time_minutes: number | null;
  servings: number | null;
}

// deno-lint-ignore no-explicit-any
export default async function handler(req: any, res: any) {
  const id = String(req.query?.id ?? "").trim();
  const host = String(req.headers?.["x-forwarded-host"] ?? req.headers?.host ?? "");
  const pageUrl = `https://${host}/recipe/${encodeURIComponent(id)}`;

  const recipe = isUuid(id) ? await fetchRecipe(id) : null;

  const title = recipe?.title
    ? `${recipe.emoji ?? ""} ${recipe.title}`.trim()
    : "Adaptable";
  const description =
    recipe?.description ?? "AI recipes that adapt to you. Generate, cook, vote.";
  const image = recipe?.image_url || `https://${host}/apple-touch-icon.png`;
  // Hero images are attached asynchronously after recipe create. Cache
  // aggressively only once image_url is present; otherwise keep TTL short
  // so crawlers pick up the dish photo soon after it lands.
  const cacheControl = recipe?.image_url
    ? "public, max-age=300, s-maxage=3600"
    : "public, max-age=0, s-maxage=60, must-revalidate";

  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.setHeader("Cache-Control", cacheControl);
  res.status(200).send(renderHtml({ title, description, image, pageUrl }));
}

async function fetchRecipe(id: string): Promise<RecipeMeta | null> {
  try {
    const url =
      `${SUPABASE_URL}/rest/v1/recipes?id=eq.${id}` +
      `&select=title,description,emoji,image_url,cuisine,difficulty,prep_time_minutes,cook_time_minutes,servings`;
    const resp = await fetch(url, {
      headers: {
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
        Accept: "application/vnd.pgrst.object+json",
      },
    });
    if (!resp.ok) return null;
    return (await resp.json()) as RecipeMeta;
  } catch {
    return null;
  }
}

function renderHtml(m: {
  title: string;
  description: string;
  image: string;
  pageUrl: string;
}): string {
  const t = esc(m.title);
  const d = esc(m.description);
  const img = esc(m.image);
  const u = esc(m.pageUrl);
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>${t}</title>
    <meta name="description" content="${d}" />
    <meta property="og:type" content="article" />
    <meta property="og:site_name" content="Adaptable" />
    <meta property="og:title" content="${t}" />
    <meta property="og:description" content="${d}" />
    <meta property="og:image" content="${img}" />
    <meta property="og:url" content="${u}" />
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content="${t}" />
    <meta name="twitter:description" content="${d}" />
    <meta name="twitter:image" content="${img}" />
    <link rel="canonical" href="${u}" />
  </head>
  <body>
    <p>${t}</p>
    <p>${d}</p>
    <a href="${u}">Open in Adaptable</a>
  </body>
</html>`;
}

function isUuid(s: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);
}

function esc(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
