/**
 * Generate a photorealistic dish cover and upload to Supabase Storage
 * (recipe-covers bucket). Returns a public URL or null.
 *
 * Strategy:
 *  1. Gemini native image models (several IDs for API surface churn)
 *  2. Imagen 3 predict (if enabled on the key)
 *  3. Pollinations food-photo fallback (always available, no key)
 */

const IMAGE_MODELS = [
  "gemini-2.5-flash-image",
  "gemini-2.5-flash-image-preview",
  "gemini-3.1-flash-image",
  "gemini-3.1-flash-image-preview",
  "gemini-3-pro-image-preview",
  "gemini-2.0-flash-preview-image-generation",
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
    `Appetizing, natural window light, shallow depth of field, restaurant quality plating, ` +
    `no text, no watermark, no hands, square composition, high detail photorealistic.`;

  let image = await generateFoodImageGemini(opts.geminiKey, prompt);
  if (!image) {
    console.warn("Gemini image failed; trying Pollinations fallback for", opts.title);
    image = await generateFoodImagePollinations(opts.title, opts.cuisine);
  }
  if (!image) return null;

  const ext = image.mimeType.includes("png") ? "png" : "jpg";
  const path = `${opts.userId}/${opts.recipeId}.${ext}`;
  const bytes = base64ToBytes(image.base64);

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

function base64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function generateFoodImageGemini(
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
            responseModalities: ["TEXT", "IMAGE"],
            // Some stacks use snake_case:
            // deno-lint-ignore no-explicit-any
            ...({ response_modalities: ["TEXT", "IMAGE"] } as any),
          },
        }),
      });
      if (!res.ok) {
        const detail = await res.text().catch(() => "");
        console.error("image model failed", model, res.status, detail.slice(0, 240));
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
      console.error("image model returned no inline data", model);
    } catch (e) {
      console.error("image gen error", model, e);
    }
  }

  // Imagen 3 predict (paid tier on some keys)
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
      console.error("imagen failed", res.status, (await res.text()).slice(0, 240));
    }
  } catch (e) {
    console.error("imagen error", e);
  }

  return null;
}

/** Reliable free fallback so backfill never soft-fails on model availability. */
async function generateFoodImagePollinations(
  title: string,
  cuisine?: string,
): Promise<{ base64: string; mimeType: string } | null> {
  try {
    const prompt = encodeURIComponent(
      `professional food photography, plated ${title}, ${cuisine ?? "delicious"} cuisine, natural light, shallow depth of field, no text, no watermark`,
    );
    const url =
      `https://image.pollinations.ai/prompt/${prompt}?width=1024&height=1024&nologo=true&enhance=true`;
    const res = await fetch(url, {
      headers: { Accept: "image/*" },
      signal: AbortSignal.timeout(45_000),
    });
    if (!res.ok) {
      console.error("pollinations failed", res.status);
      return null;
    }
    const buf = new Uint8Array(await res.arrayBuffer());
    if (buf.byteLength < 1000) return null;
    // base64 encode without stack blowups
    let binary = "";
    const chunk = 0x8000;
    for (let i = 0; i < buf.length; i += chunk) {
      binary += String.fromCharCode(...buf.subarray(i, i + chunk));
    }
    const mime =
      res.headers.get("content-type")?.split(";")[0] || "image/jpeg";
    return { base64: btoa(binary), mimeType: mime };
  } catch (e) {
    console.error("pollinations error", e);
    return null;
  }
}
