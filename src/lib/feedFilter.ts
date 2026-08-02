import type { Recipe } from "./types";

/** Chip kinds that drive Discover filtering. Mirrors iOS `FeedFilter.Chip`. */
export type FeedChip =
  | { kind: "all" }
  | { kind: "foryou" }
  | { kind: "following" }
  | { kind: "time"; maxMinutes: number }
  | { kind: "cal"; maxCalories: number }
  | { kind: "protein"; minProtein: number }
  | { kind: "tag"; label: string };

/**
 * Pure feed filter shared by Discover. Keep in lockstep with
 * `ios/.../Utilities/FeedFilter.swift`.
 */
export function filterFeedRecipes(
  recipes: Recipe[],
  search: string,
  chip: FeedChip,
  dietTags: string[],
  followedAuthorIds: Set<string>,
): Recipe[] {
  const q = search.trim().toLowerCase();
  const diets = dietTags.map((d) => d.toLowerCase());

  return recipes.filter((r) => {
    if (q) {
      const haystack = [r.title, r.description, r.cuisine, ...r.tags]
        .join(" ")
        .toLowerCase();
      if (!haystack.includes(q)) return false;
    }

    switch (chip.kind) {
      case "time":
        return r.prep_time_minutes + r.cook_time_minutes <= chip.maxMinutes;
      case "cal":
        // Recipes without calorie data can't claim to be low-cal.
        return r.calories !== null && r.calories <= chip.maxCalories;
      case "protein":
        return (
          (r.protein_g !== null && r.protein_g >= chip.minProtein) ||
          r.tags.some((t) => t.toLowerCase() === "high-protein")
        );
      case "foryou":
        if (diets.length === 0) return false;
        return r.tags.some((t) => diets.includes(t.toLowerCase()));
      case "following":
        return followedAuthorIds.has(r.author_id);
      case "tag":
        return r.tags.some(
          (t) => t.toLowerCase() === chip.label.toLowerCase(),
        );
      default:
        return true;
    }
  });
}
