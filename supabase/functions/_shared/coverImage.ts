/**
 * Generate a photorealistic dish cover via Gemini image models and upload
 * to Supabase Storage (recipe-covers bucket). Returns a public URL or null.
 */

const IMAGE_MODELS = [
  "gemini-2.0-flash-preview-image-generation",
  "gemini-2.5-flash-image-preview",
  "gemini-2.0-flash-exp-image-generation",
];

export async function generateAndUploadCover(opts: {
  // deno-lint-ignore no-explicit-any
  supabase: any;
  geminiKey: string;
  userId: string;
  recipeId: string;
  title: string;
  description?: string;
  cuisine?: string;
  emoji?: string;
}): Promise<string | null> {
  const prompt =
    `Professional food photography of a plated dish: ${opts.title}. ` +
    `${opts.description ? opts.description.slice(0, 180) + ". " : ""}` +
    `${opts.cuisine ? opts.cuisine + " cuisine. " : ""}` +
    `Appetizing, natural lighting, shallow depth of field, restaurant quality, ` +
    `no text, no watermark, no hands, square composition, high detail.`;

  const image = await generateFoodImage(opts.geminiKey, prompt);
  if (!image) return null;

  const path = `${opts.userId}/${opts.recipeId}.jpg`;
  const bytes = Uint8Array.from(atob(image.base64), (c) => c.charCodeAt(0));

  const { error: upErr } = await opts.supabase.storage
    .from("recipe-covers")
    .upload(path, bytes, {
      contentType: image.mimeType || "image/jpeg",
      upsert: true,
    });

  if (upErr) {
    console.error("cover upload failed", upErr);
    return null;
  }

  const { data } = opts.supabase.storage.from("recipe-covers").getPublicUrl(path);
  return data?.publicUrl ?? null;
}

async function generateFoodImage(
  geminiKey: string,
  prompt: string,
): Promise<{ base64: string; mimeType: string } | null> {
  for (const model of IMAGE_MODELS) {
    try {
      const url =
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiKey}`;
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: {
            // Image-capable Gemini models accept responseModalities.
            responseModalities: ["TEXT", "IMAGE"],
          },
        }),
      });
      if (!res.ok) {
        const detail = await res.text().catch(() => "");
        console.error("image model failed", model, res.status, detail.slice(0, 200));
        continue;
      }
      const json = await res.json();
      const parts = json?.candidates?.[0]?.content?.parts ?? [];
      for (const part of parts) {
        const inline = part.inlineData || part.inline_data;
        if (inline?.data) {
          return {
            base64: inline.data,
            mimeType: inline.mimeType || inline.mime_type || "image/jpeg",
          };
        }
      }
    } catch (e) {
      console.error("image gen error", model, e);
    }
  }

  // Last resort: Imagen 3 predict API shape (if enabled on the key).
  try {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-002:predict?key=${geminiKey}`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        instances: [{ prompt }],
        parameters: { sampleCount: 1, aspectRatio: "1:1" },
      }),
    });
    if (res.ok) {
      const json = await res.json();
      const b64 =
        json?.predictions?.[0]?.bytesBase64Encoded ||
        json?.predictions?.[0]?.image?.bytesBase64Encoded;
      if (b64) return { base64: b64, mimeType: "image/jpeg" };
    } else {
      console.error("imagen failed", res.status, (await res.text()).slice(0, 200));
    }
  } catch (e) {
    console.error("imagen error", e);
  }

  return null;
}
