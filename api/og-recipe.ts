/**
 * Open Graph HTML for recipe share links.
 * Served to crawlers (iMessage, Slack, Twitter, etc.) via middleware rewrite
 * so link previews show title, description, and image instead of the SPA shell.
 *
 * Runtime: Vercel Edge. Fetches public recipe rows from Supabase REST (RLS
 * allows anonymous select on recipes).
 */

export const config = { runtime: "edge" };

const SITE_URL = (
  process.env.VITE_SITE_URL ||
  process.env.SITE_URL ||
  "https://adaptable-pi.vercel.app"
).replace(/\/$/, "");

const SUPABASE_URL = (
  process.env.VITE_SUPABASE_URL ||
  process.env.SUPABASE_URL ||
  "https://ypziulvtfsyrwpotlevp.supabase.co"
).replace(/\/$/, "");

const SUPABASE_ANON_KEY =
  process.env.VITE_SUPABASE_ANON_KEY ||
  process.env.SUPABASE_ANON_KEY ||
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlweml1bHZ0ZnN5cndwb3RsZXZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMwNzY4MjYsImV4cCI6MjA5ODY1MjgyNn0.MQ_Cm60vcs46ErhyzBz5WPC69zQLewhS2WmExKjnk5Y";

interface RecipeRow {
  id: string;
  title: string | null;
  description: string | null;
  emoji: string | null;
  cuisine: string | null;
  difficulty: string | null;
  prep_time_minutes: number | null;
  cook_time_minutes: number | null;
  servings: number | null;
  image_url: string | null;
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function totalMinutes(prep: number, cook: number): string {
  const total = prep + cook;
  if (total <= 0) return "";
  if (total >= 60) {
    const h = Math.floor(total / 60);
    const m = total % 60;
    return m ? `${h} hr ${m} min` : `${h} hr`;
  }
  return `${total} min`;
}

function buildDescription(r: RecipeRow): string {
  const bits: string[] = [];
  if (r.description?.trim()) bits.push(r.description.trim());
  const meta: string[] = [];
  const mins = totalMinutes(r.prep_time_minutes ?? 0, r.cook_time_minutes ?? 0);
  if (mins) meta.push(mins);
  if (r.difficulty) meta.push(r.difficulty);
  if (r.servings) meta.push(`Serves ${r.servings}`);
  if (r.cuisine) meta.push(r.cuisine);
  if (meta.length) bits.push(meta.join(" · "));
  bits.push("AI recipes that adapt to you — open in Adaptable.");
  return bits.join("\n");
}

async function fetchRecipe(id: string): Promise<RecipeRow | null> {
  const url = `${SUPABASE_URL}/rest/v1/recipes?id=eq.${encodeURIComponent(id)}&select=id,title,description,emoji,cuisine,difficulty,prep_time_minutes,cook_time_minutes,servings,image_url&limit=1`;
  const res = await fetch(url, {
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      Accept: "application/json",
    },
  });
  if (!res.ok) return null;
  const rows = (await res.json()) as RecipeRow[];
  return rows[0] ?? null;
}

function ogHtml(opts: {
  title: string;
  description: string;
  url: string;
  image: string;
  emoji?: string;
}): string {
  const title = escapeHtml(opts.title);
  const description = escapeHtml(opts.description);
  const url = escapeHtml(opts.url);
  const image = escapeHtml(opts.image);
  const emoji = opts.emoji ? escapeHtml(opts.emoji) : "🍳";

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${title}</title>
  <meta name="description" content="${description}" />
  <link rel="canonical" href="${url}" />

  <meta property="og:type" content="article" />
  <meta property="og:site_name" content="Adaptable" />
  <meta property="og:title" content="${title}" />
  <meta property="og:description" content="${description}" />
  <meta property="og:url" content="${url}" />
  <meta property="og:image" content="${image}" />
  <meta property="og:image:width" content="1024" />
  <meta property="og:image:height" content="1024" />

  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${title}" />
  <meta name="twitter:description" content="${description}" />
  <meta name="twitter:image" content="${image}" />

  <style>
    body { font-family: -apple-system, system-ui, sans-serif; margin: 0; min-height: 100vh;
      display: grid; place-items: center; background: #0c0a09; color: #faf8f5; }
    .card { text-align: center; padding: 2rem; max-width: 28rem; }
    .emoji { font-size: 4rem; }
    h1 { font-size: 1.5rem; margin: 0.75rem 0 0.5rem; }
    p { opacity: 0.75; line-height: 1.45; }
    a { color: #f97316; font-weight: 700; }
  </style>
</head>
<body>
  <div class="card">
    <div class="emoji">${emoji}</div>
    <h1>${title}</h1>
    <p>${description.replace(/\n/g, "<br/>")}</p>
    <p><a href="${url}">Open recipe in Adaptable</a></p>
  </div>
  <script>location.replace(${JSON.stringify(opts.url)});</script>
</body>
</html>`;
}

export default async function handler(request: Request): Promise<Response> {
  const reqUrl = new URL(request.url);
  const id = (reqUrl.searchParams.get("id") || "").trim();

  if (!id) {
    return new Response("Missing recipe id", { status: 400 });
  }

  const recipeUrl = `${SITE_URL}/recipe/${id}`;
  const fallbackImage = `${SITE_URL}/apple-touch-icon.png`;

  try {
    const recipe = await fetchRecipe(id);
    if (!recipe) {
      const html = ogHtml({
        title: "Recipe · Adaptable",
        description: "This recipe may have been removed. Browse more on Adaptable.",
        url: recipeUrl,
        image: fallbackImage,
      });
      return new Response(html, {
        status: 404,
        headers: {
          "content-type": "text/html; charset=utf-8",
          "cache-control": "public, s-maxage=60, stale-while-revalidate=300",
        },
      });
    }

    const emoji = recipe.emoji?.trim() || "🍳";
    const name = recipe.title?.trim() || "Recipe";
    const title = `${emoji} ${name}`;
    const description = buildDescription(recipe);
    const image = recipe.image_url?.trim() || fallbackImage;

    const html = ogHtml({
      title,
      description,
      url: recipeUrl,
      image,
      emoji,
    });

    return new Response(html, {
      status: 200,
      headers: {
        "content-type": "text/html; charset=utf-8",
        // Recipes change rarely; crawlers can cache for a bit.
        "cache-control": "public, s-maxage=300, stale-while-revalidate=86400",
      },
    });
  } catch {
    const html = ogHtml({
      title: "Adaptable",
      description: "AI recipes that adapt to you.",
      url: recipeUrl,
      image: fallbackImage,
    });
    return new Response(html, {
      status: 200,
      headers: {
        "content-type": "text/html; charset=utf-8",
        "cache-control": "public, s-maxage=60",
      },
    });
  }
}
