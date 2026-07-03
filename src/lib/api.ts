import { supabase, isDemo } from "./supabase";
import { demoStore, demoGenerate } from "./demo";
import type { FeedSort, Recipe, VoteValue } from "./types";

const RECIPE_SELECT = "*, author:profiles(id, username, avatar_url)";

export async function fetchFeed(sort: FeedSort): Promise<Recipe[]> {
  if (isDemo) {
    const list = demoStore.listRecipes();
    return sort === "top"
      ? list.sort((a, b) => b.net_upvotes - a.net_upvotes)
      : list.sort((a, b) => b.created_at.localeCompare(a.created_at));
  }
  let query = supabase!.from("recipes").select(RECIPE_SELECT).limit(50);
  query =
    sort === "top"
      ? query.order("net_upvotes", { ascending: false }).order("created_at", { ascending: false })
      : query.order("created_at", { ascending: false });
  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []) as Recipe[];
}

export async function fetchRecipe(id: string): Promise<Recipe | null> {
  if (isDemo) return demoStore.getRecipe(id) ?? null;
  const { data, error } = await supabase!
    .from("recipes")
    .select(RECIPE_SELECT)
    .eq("id", id)
    .maybeSingle();
  if (error) throw error;
  return data as Recipe | null;
}

/** Map of recipe_id → the current user's vote. */
export async function fetchMyVotes(userId: string): Promise<Record<string, VoteValue>> {
  if (isDemo) return demoStore.getVotes();
  const { data, error } = await supabase!
    .from("user_votes")
    .select("recipe_id, value")
    .eq("user_id", userId);
  if (error) throw error;
  return Object.fromEntries(
    (data ?? []).map((v) => [v.recipe_id as string, v.value as VoteValue]),
  );
}

export async function setVote(
  userId: string,
  recipeId: string,
  value: VoteValue | null,
): Promise<void> {
  if (isDemo) {
    demoStore.setVote(recipeId, value);
    return;
  }
  if (value === null) {
    const { error } = await supabase!
      .from("user_votes")
      .delete()
      .eq("user_id", userId)
      .eq("recipe_id", recipeId);
    if (error) throw error;
  } else {
    const { error } = await supabase!
      .from("user_votes")
      .upsert({ user_id: userId, recipe_id: recipeId, value });
    if (error) throw error;
  }
}

export async function fetchMySaveIds(userId: string): Promise<string[]> {
  if (isDemo) return demoStore.getSaves();
  const { data, error } = await supabase!
    .from("saves")
    .select("recipe_id")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return (data ?? []).map((s) => s.recipe_id as string);
}

export async function fetchSavedRecipes(userId: string): Promise<Recipe[]> {
  if (isDemo) {
    const ids = demoStore.getSaves();
    return ids
      .map((id) => demoStore.getRecipe(id))
      .filter((r): r is Recipe => Boolean(r));
  }
  const { data, error } = await supabase!
    .from("saves")
    .select(`recipe:recipes(${RECIPE_SELECT})`)
    .eq("user_id", userId)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return (data ?? [])
    .map((row) => row.recipe as unknown as Recipe)
    .filter(Boolean);
}

/** Returns the new saved state. */
export async function toggleSave(
  userId: string,
  recipeId: string,
  currentlySaved: boolean,
): Promise<boolean> {
  if (isDemo) return demoStore.toggleSave(recipeId);
  if (currentlySaved) {
    const { error } = await supabase!
      .from("saves")
      .delete()
      .eq("user_id", userId)
      .eq("recipe_id", recipeId);
    if (error) throw error;
    return false;
  }
  const { error } = await supabase!
    .from("saves")
    .upsert({ user_id: userId, recipe_id: recipeId });
  if (error) throw error;
  return true;
}

export async function generateRecipe(prompt: string): Promise<Recipe> {
  if (isDemo) return demoGenerate(prompt);
  const { data, error } = await supabase!.functions.invoke("generate-recipe", {
    body: { prompt },
  });
  if (error) throw new Error(error.message ?? "Generation failed");
  if (data?.error) throw new Error(data.error);
  return data.recipe as Recipe;
}
