// Extract visible pantry ingredients from a fridge / counter photo.

const GEMINI_MODELS = [
  "gemini-2.5-flash",
  "gemini-2.5-flash-lite",
  "gemini-flash-latest",
];

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const schema = {
  type: "OBJECT",
  properties: {
    ingredients: { type: "ARRAY", items: { type: "STRING" } },
  },
  required: ["ingredients"],
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => null);
    const image = typeof body?.image_base64 === "string" ? body.image_base64 : "";
    const mime = typeof body?.mime_type === "string" ? body.mime_type : "image/jpeg";
    if (!image || image.length > 6_000_000) {
      return json({ error: "Send a fridge photo under ~4 MB." }, 400);
    }

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) return json({ error: "Recipe engine is not configured." }, 500);

    const payload = {
      contents: [
        {
          role: "user",
          parts: [
            {
              text:
                "List the recognizable food ingredients in this fridge or counter photo. " +
                "Short grocery names only (e.g. Eggs, Chicken, Spinach). 3–12 items. Skip condiments like salt.",
            },
            { inline_data: { mime_type: mime, data: image } },
          ],
        },
      ],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: schema,
        temperature: 0.2,
      },
    };

    for (const model of GEMINI_MODELS) {
      const url =
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiKey}`;
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      if (res.status === 404) continue;
      if (!res.ok) break;
      const data = await res.json();
      const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (typeof text === "string") {
        const parsed = JSON.parse(text);
        const items = Array.isArray(parsed.ingredients)
          ? parsed.ingredients.map(String).map((s: string) => s.trim()).filter(Boolean).slice(0, 12)
          : [];
        return json({ ingredients: items }, 200);
      }
    }
    return json({ error: "Couldn't read that photo — try a brighter shot." }, 502);
  } catch (e) {
    console.error("read-fridge", e);
    return json({ error: "Couldn't read that photo — try again." }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
