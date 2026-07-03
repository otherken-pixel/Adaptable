import type { Recipe } from "./types";

/**
 * Hacker-News-style time-decayed heat score. Cooking a recipe is the
 * strongest signal (someone actually made it), then comments, then votes.
 */
export function trendingScore(recipe: Recipe, now = Date.now()): number {
  const hours = Math.max(
    0,
    (now - new Date(recipe.created_at).getTime()) / 3_600_000,
  );
  const heat =
    recipe.net_upvotes + 3 * recipe.cook_count + 2 * recipe.comment_count + 1;
  return heat / Math.pow(hours + 2, 1.4);
}

export function sortByTrending(rows: Recipe[]): Recipe[] {
  const now = Date.now();
  return [...rows].sort((a, b) => trendingScore(b, now) - trendingScore(a, now));
}
