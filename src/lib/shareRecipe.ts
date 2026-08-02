import type { Recipe } from "./types";
import { totalMinutes } from "./format";
import { scaleQuantity } from "./quantity";
import { recipeShareURL, SITE_URL } from "./site";

export interface SharePayload {
  title: string;
  /** Full recipe body without trailing URL (for Web Share `text` + separate `url`). */
  text: string;
  /** Full recipe body including URL (clipboard / plain-text targets). */
  textWithUrl: string;
  url: string;
  /** Dish photo when available (for Web Share `files` / iMessage). */
  imageUrl?: string | null;
}

/**
 * Build a best-in-class share payload for iMessage and other targets:
 * full scaled recipe as plain text (cookable without the app) + deep link URL
 * + optional dish cover photo.
 */
export function buildRecipeShare(
  recipe: Recipe,
  servings: number = recipe.servings,
): SharePayload {
  const factor = recipe.servings > 0 ? servings / recipe.servings : 1;
  const url = recipeShareURL(recipe.id);
  const emoji = recipe.emoji?.trim() || "🍳";
  const title = recipe.title?.trim() || "Recipe";
  const lines: string[] = [];

  lines.push(`${emoji} ${title}`);
  lines.push("");

  if (recipe.description?.trim()) {
    lines.push(recipe.description.trim());
    lines.push("");
  }

  const meta: string[] = [];
  const mins = totalMinutes(
    recipe.prep_time_minutes ?? 0,
    recipe.cook_time_minutes ?? 0,
  );
  if (mins) meta.push(`⏱ ${mins}`);
  if (recipe.difficulty) meta.push(recipe.difficulty);
  meta.push(`Serves ${servings}`);
  lines.push(meta.join(" · "));
  lines.push("");

  const ingredients = recipe.ingredients ?? [];
  if (ingredients.length > 0) {
    lines.push("INGREDIENTS");
    for (const ing of ingredients) {
      const qty = scaleQuantity(ing.quantity, factor);
      const note = ing.note?.trim() ? ` (${ing.note.trim()})` : "";
      const qtyPart = qty?.trim() ? `${qty.trim()} ` : "";
      lines.push(`• ${qtyPart}${ing.item}${note}`);
    }
    lines.push("");
  }

  const steps = recipe.steps ?? [];
  if (steps.length > 0) {
    lines.push("METHOD");
    for (const step of steps) {
      lines.push(`${step.step}. ${step.instruction.trim()}`);
      if (step.tip?.trim()) {
        lines.push(`   💡 ${step.tip.trim()}`);
      }
    }
    lines.push("");
  }

  lines.push("Made with Adaptable");
  const text = lines.join("\n").trim();
  const textWithUrl = `${text}\n${url}`;

  return {
    title: `${emoji} ${title}`,
    text,
    textWithUrl,
    url,
    imageUrl: recipe.image_url ?? null,
  };
}

/** Fetch dish cover as a File for Web Share Level 2 (when supported). */
export async function fetchShareImageFile(
  imageUrl: string | null | undefined,
  title: string,
): Promise<File | null> {
  if (!imageUrl) return null;
  try {
    const res = await fetch(imageUrl, { mode: "cors" });
    if (!res.ok) return null;
    const blob = await res.blob();
    if (blob.size < 500) return null;
    const type = blob.type || "image/jpeg";
    const ext = type.includes("png") ? "png" : "jpg";
    const safe =
      title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-|-$/g, "")
        .slice(0, 40) || "recipe";
    return new File([blob], `${safe}.${ext}`, { type });
  } catch {
    return null;
  }
}

/**
 * Share via Web Share API with dish photo when the browser allows files
 * (notably Safari/iOS → Messages). Falls back to text + URL, then clipboard.
 */
export async function shareRecipe(
  recipe: Recipe,
  servings: number = recipe.servings,
): Promise<void> {
  const payload = buildRecipeShare(recipe, servings);
  const file = await fetchShareImageFile(payload.imageUrl, recipe.title);

  if (navigator.share) {
    // Prefer photo + text when the target supports files (iMessage on iOS).
    if (file) {
      const withFiles: ShareData = {
        title: payload.title,
        text: payload.text,
        url: payload.url,
        files: [file],
      };
      try {
        if (navigator.canShare?.(withFiles)) {
          await navigator.share(withFiles);
          return;
        }
      } catch (e) {
        // User cancel vs unsupported — only rethrow cancel? Fall through.
        if (e instanceof DOMException && e.name === "AbortError") return;
      }
    }
    try {
      await navigator.share({
        title: payload.title,
        text: payload.text,
        url: payload.url,
      });
      return;
    } catch (e) {
      if (e instanceof DOMException && e.name === "AbortError") return;
    }
  }

  await navigator.clipboard.writeText(payload.textWithUrl);
}

export { SITE_URL, recipeShareURL };
