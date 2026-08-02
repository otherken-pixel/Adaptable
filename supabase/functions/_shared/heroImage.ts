// Shared helper: generate an AI "dish photo" hero for a recipe.
//
// Used by both generate-recipe and import-recipe. Everything here is
// best-effort — if image generation, upload, or the row update fails, we
// log and move on. The recipe already exists; the UI simply falls back to
// the emoji-on-gradient hero until (or unless) an image lands.
//
// The image model is asked for a 16:9 photograph so the same asset works
// as an in-app hero banner AND as the `og:image` on a shared recipe link
// (which wants a wide summary_large_image card).

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

// Google's image model. `gemini-2.5-flash-image` ("Nano Banana") returns
// the picture as inline_data on the standard generateContent endpoint —
// the same host/auth the text models already use. Override with the
// IMAGE_MODEL secret if the project is provisioned for a different one.
const IMAGE_MODEL = Deno.env.get("IMAGE_MODEL") ?? "gemini-2.5-flash-image";
const IMAGE_BUCKET = "recipe-images";

interface RecipeLike {
  id: string;
  author_id?: string | null;
  title?: string | null;
  description?: string | null;
  cuisine?: string | null;
}

/**
 * Generates a hero image for `recipe`, uploads it to the public
 * recipe-images bucket, and patches recipes.image_url / image_path.
 * Never throws — resolves whether or not an image was produced.
 *
 * Runs well under `EdgeRuntime.waitUntil(...)` so the caller can return
 * the recipe immediately and let the image arrive a few seconds later.
 */
export async function attachHeroImage(
  supabase: SupabaseClient,
  geminiKey: string,
  recipe: RecipeLike,
): Promise<void> {
  try {
    if (!recipe?.id || !recipe.author_id) return;

    const image = await generateFoodPhoto(geminiKey, recipe);
    if (!image) return;

    const ext = image.mimeType.includes("jpeg") ? "jpg" : "png";
    const path = `${recipe.author_id}/${recipe.id}.${ext}`;

    const { error: upErr } = await supabase.storage
      .from(IMAGE_BUCKET)
      .upload(path, image.bytes, {
        contentType: image.mimeType,
        upsert: true,
      });
    if (upErr) {
      console.error("Hero image upload failed", upErr.message);
      return;
    }

    const publicUrl = supabase.storage.from(IMAGE_BUCKET).getPublicUrl(path)
      .data.publicUrl;

    const { error: updErr } = await supabase
      .from("recipes")
      .update({ image_url: publicUrl, image_path: path })
      .eq("id", recipe.id);
    if (updErr) console.error("Hero image row update failed", updErr.message);
  } catch (err) {
    console.error("attachHeroImage error", err instanceof Error ? err.message : err);
  }
}

/** Builds an appetizing food-photography prompt from the recipe fields. */
function photoPrompt(recipe: RecipeLike): string {
  const title = (recipe.title ?? "a delicious dish").slice(0, 120);
  const description = (recipe.description ?? "").slice(0, 200);
  const cuisine = recipe.cuisine ? `${recipe.cuisine} ` : "";
  return (
    `A professional, appetizing food photograph of ${cuisine}"${title}". ` +
    (description ? `${description} ` : "") +
    "Beautifully plated and served, natural soft lighting, shallow depth of " +
    "field, styled on a clean surface, high detail, mouth-watering. " +
    "Wide 16:9 composition. No text, no words, no watermark, no hands, no cutlery labels."
  );
}

interface GeneratedImage {
  bytes: Uint8Array;
  mimeType: string;
}

/** Calls the Gemini image model and extracts the first inline image. */
async function generateFoodPhoto(
  geminiKey: string,
  recipe: RecipeLike,
): Promise<GeneratedImage | null> {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${IMAGE_MODEL}:generateContent?key=${geminiKey}`;

  let res: Response;
  try {
    res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: photoPrompt(recipe) }] }],
        generationConfig: { responseModalities: ["IMAGE"] },
      }),
      signal: AbortSignal.timeout(45_000),
    });
  } catch (err) {
    console.error("Image model request failed", err instanceof Error ? err.message : err);
    return null;
  }

  if (!res.ok) {
    console.error("Image model error", res.status, (await res.text()).slice(0, 300));
    return null;
  }

  const jsonRes = await res.json();
  const parts = jsonRes?.candidates?.[0]?.content?.parts ?? [];
  // deno-lint-ignore no-explicit-any
  const inline = parts.find((p: any) => p?.inline_data?.data ?? p?.inlineData?.data);
  const data = inline?.inline_data?.data ?? inline?.inlineData?.data;
  const mimeType = inline?.inline_data?.mime_type ?? inline?.inlineData?.mimeType ??
    "image/png";
  if (!data) {
    console.error("Image model returned no image data");
    return null;
  }

  return { bytes: base64ToBytes(data), mimeType };
}

function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}
