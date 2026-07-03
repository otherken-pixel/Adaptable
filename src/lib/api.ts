import { supabase, isDemo } from "./supabase";
import { demoStore, demoGenerate, demoImport } from "./demo";
import { shoppingLocal } from "./shoppingLocal";
import { sortByTrending } from "./trending";
import type {
  AppNotification,
  Comment,
  FeedSort,
  MealPlanEntry,
  Recipe,
  RecipePhoto,
  ShoppingItem,
  VoteValue,
} from "./types";

const RECIPE_SELECT = "*, author:profiles(id, username, avatar_url)";
const COMMENT_SELECT = "*, author:profiles(id, username, avatar_url)";

export async function fetchFeed(sort: FeedSort): Promise<Recipe[]> {
  if (isDemo) {
    const list = demoStore.listRecipes();
    if (sort === "top") return list.sort((a, b) => b.net_upvotes - a.net_upvotes);
    if (sort === "new") return list.sort((a, b) => b.created_at.localeCompare(a.created_at));
    return sortByTrending(list);
  }
  let query = supabase!.from("recipes").select(RECIPE_SELECT).limit(50);
  // "hot" fetches the newest window and ranks it with the time-decayed
  // trending score client-side (cheap at feed scale, no DB function needed).
  query =
    sort === "top"
      ? query.order("net_upvotes", { ascending: false }).order("created_at", { ascending: false })
      : query.order("created_at", { ascending: false });
  const { data, error } = await query;
  if (error) throw error;
  const rows = (data ?? []) as Recipe[];
  return sort === "hot" ? sortByTrending(rows) : rows;
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

/* ---- Comments ---- */

export async function fetchComments(recipeId: string): Promise<Comment[]> {
  if (isDemo) return demoStore.listComments(recipeId);
  const { data, error } = await supabase!
    .from("comments")
    .select(COMMENT_SELECT)
    .eq("recipe_id", recipeId)
    .order("created_at", { ascending: false })
    .limit(100);
  if (error) throw error;
  return (data ?? []) as Comment[];
}

export async function addComment(
  userId: string,
  recipeId: string,
  body: string,
): Promise<Comment> {
  if (isDemo) return demoStore.addComment(recipeId, body);
  const { data, error } = await supabase!
    .from("comments")
    .insert({ user_id: userId, recipe_id: recipeId, body })
    .select(COMMENT_SELECT)
    .single();
  if (error) throw error;
  return data as Comment;
}

export async function deleteComment(userId: string, commentId: string): Promise<void> {
  if (isDemo) {
    demoStore.deleteComment(commentId);
    return;
  }
  const { error } = await supabase!
    .from("comments")
    .delete()
    .eq("user_id", userId)
    .eq("id", commentId);
  if (error) throw error;
}

/* ---- Cooks ("Cooked it" — feeds the Trending sort) ---- */

export async function recordCook(userId: string, recipeId: string): Promise<void> {
  if (isDemo) {
    demoStore.recordCook(recipeId);
    return;
  }
  const { error } = await supabase!
    .from("cooks")
    .insert({ user_id: userId, recipe_id: recipeId });
  if (error) throw error;
}

/* ---- Notifications (in-app inbox, Supabase Realtime) ---- */

export async function fetchNotifications(userId: string): Promise<AppNotification[]> {
  if (isDemo) return demoStore.listNotifications();
  const { data, error } = await supabase!
    .from("notifications")
    .select(
      "*, actor:profiles!notifications_actor_id_fkey(id, username, avatar_url), recipe:recipes(id, title, emoji)",
    )
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(50);
  if (error) throw error;
  return (data ?? []) as AppNotification[];
}

export async function markNotificationsRead(userId: string): Promise<void> {
  if (isDemo) {
    demoStore.markNotificationsRead();
    return;
  }
  const { error } = await supabase!
    .from("notifications")
    .update({ read: true })
    .eq("user_id", userId)
    .eq("read", false);
  if (error) throw error;
}

/* ---- Push notification device tokens ---- */

export async function registerDeviceToken(
  userId: string,
  token: string,
  platform: "ios" | "android" | "web" | "unknown",
): Promise<void> {
  if (isDemo) return;
  const { error } = await supabase!
    .from("device_tokens")
    .upsert({ token, user_id: userId, platform });
  if (error) throw error;
}

/* ---- Shopping list ---- */

export async function fetchShoppingItems(userId: string): Promise<ShoppingItem[]> {
  if (isDemo) return shoppingLocal.list();
  const { data, error } = await supabase!
    .from("shopping_items")
    .select("id, recipe_id, recipe_title, item, quantity, checked, created_at")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as ShoppingItem[];
}

export async function addShoppingItems(
  userId: string,
  rows: Array<Pick<ShoppingItem, "recipe_id" | "recipe_title" | "item" | "quantity">>,
): Promise<ShoppingItem[]> {
  if (isDemo) return shoppingLocal.add(rows);
  const { data, error } = await supabase!
    .from("shopping_items")
    .insert(rows.map((r) => ({ ...r, user_id: userId })))
    .select("id, recipe_id, recipe_title, item, quantity, checked, created_at");
  if (error) throw error;
  return (data ?? []) as ShoppingItem[];
}

export async function setShoppingItemChecked(
  userId: string,
  id: string,
  checked: boolean,
): Promise<void> {
  if (isDemo) {
    shoppingLocal.setChecked(id, checked);
    return;
  }
  const { error } = await supabase!
    .from("shopping_items")
    .update({ checked })
    .eq("user_id", userId)
    .eq("id", id);
  if (error) throw error;
}

export async function removeShoppingItem(userId: string, id: string): Promise<void> {
  if (isDemo) {
    shoppingLocal.remove(id);
    return;
  }
  const { error } = await supabase!
    .from("shopping_items")
    .delete()
    .eq("user_id", userId)
    .eq("id", id);
  if (error) throw error;
}

export async function clearCheckedShoppingItems(userId: string): Promise<void> {
  if (isDemo) {
    shoppingLocal.clearChecked();
    return;
  }
  const { error } = await supabase!
    .from("shopping_items")
    .delete()
    .eq("user_id", userId)
    .eq("checked", true);
  if (error) throw error;
}

/* ---- Meal planner ---- */

export async function fetchMealPlans(userId: string): Promise<MealPlanEntry[]> {
  if (isDemo) return demoStore.listPlans();
  const { data, error } = await supabase!
    .from("meal_plans")
    .select(`*, recipe:recipes(${RECIPE_SELECT})`)
    .eq("user_id", userId)
    .order("plan_date", { ascending: true });
  if (error) throw error;
  return (data ?? []) as unknown as MealPlanEntry[];
}

export async function addMealPlan(
  userId: string,
  recipeId: string,
  planDate: string,
  servings: number,
): Promise<void> {
  if (isDemo) {
    demoStore.addPlan(recipeId, planDate, servings);
    return;
  }
  const { error } = await supabase!
    .from("meal_plans")
    .insert({ user_id: userId, recipe_id: recipeId, plan_date: planDate, servings });
  if (error) throw error;
}

export async function updateMealPlanServings(
  userId: string,
  id: string,
  servings: number,
): Promise<void> {
  if (isDemo) {
    demoStore.updatePlanServings(id, servings);
    return;
  }
  const { error } = await supabase!
    .from("meal_plans")
    .update({ servings })
    .eq("user_id", userId)
    .eq("id", id);
  if (error) throw error;
}

export async function removeMealPlan(userId: string, id: string): Promise<void> {
  if (isDemo) {
    demoStore.removePlan(id);
    return;
  }
  const { error } = await supabase!
    .from("meal_plans")
    .delete()
    .eq("user_id", userId)
    .eq("id", id);
  if (error) throw error;
}

/* ---- Follows ---- */

export async function fetchFollowees(userId: string): Promise<string[]> {
  if (isDemo) return demoStore.getFollows();
  const { data, error } = await supabase!
    .from("follows")
    .select("followee_id")
    .eq("follower_id", userId);
  if (error) throw error;
  return (data ?? []).map((f) => f.followee_id as string);
}

export async function setFollow(
  userId: string,
  chefId: string,
  follow: boolean,
): Promise<void> {
  if (isDemo) {
    demoStore.toggleFollow(chefId);
    return;
  }
  if (follow) {
    const { error } = await supabase!
      .from("follows")
      .upsert({ follower_id: userId, followee_id: chefId });
    if (error) throw error;
  } else {
    const { error } = await supabase!
      .from("follows")
      .delete()
      .eq("follower_id", userId)
      .eq("followee_id", chefId);
    if (error) throw error;
  }
}

/* ---- Cooked-it photos + avatars (live mode only; storage-backed) ---- */

export async function fetchRecipePhotos(recipeId: string): Promise<RecipePhoto[]> {
  if (isDemo) return [];
  const { data, error } = await supabase!
    .from("recipe_photos")
    .select("*")
    .eq("recipe_id", recipeId)
    .order("created_at", { ascending: false })
    .limit(24);
  if (error) throw error;
  return (data ?? []).map((p) => ({
    ...p,
    url: supabase!.storage.from("cook-photos").getPublicUrl(p.path).data.publicUrl,
  })) as RecipePhoto[];
}

export async function uploadCookPhoto(
  userId: string,
  recipeId: string,
  file: File,
): Promise<RecipePhoto> {
  const ext = file.name.split(".").pop()?.toLowerCase() || "jpg";
  const path = `${userId}/${recipeId}-${Date.now()}.${ext}`;
  const { error: upErr } = await supabase!.storage
    .from("cook-photos")
    .upload(path, file, { contentType: file.type || "image/jpeg" });
  if (upErr) throw upErr;
  const { data, error } = await supabase!
    .from("recipe_photos")
    .insert({ user_id: userId, recipe_id: recipeId, path })
    .select("*")
    .single();
  if (error) throw error;
  return {
    ...(data as RecipePhoto),
    url: supabase!.storage.from("cook-photos").getPublicUrl(path).data.publicUrl,
  };
}

export async function uploadAvatar(userId: string, file: File): Promise<string> {
  const ext = file.name.split(".").pop()?.toLowerCase() || "jpg";
  const path = `${userId}/avatar-${Date.now()}.${ext}`;
  const { error: upErr } = await supabase!.storage
    .from("avatars")
    .upload(path, file, { contentType: file.type || "image/jpeg", upsert: true });
  if (upErr) throw upErr;
  const url = supabase!.storage.from("avatars").getPublicUrl(path).data.publicUrl;
  const { error } = await supabase!
    .from("profiles")
    .update({ avatar_url: url })
    .eq("id", userId);
  if (error) throw error;
  return url;
}

/* ---- Import + generation ---- */

export interface ImportSource {
  url?: string;
  text?: string;
  imageBase64?: string;
  mimeType?: string;
}

export async function importRecipe(source: ImportSource): Promise<Recipe> {
  if (isDemo) {
    return demoImport({
      url: source.url,
      text: source.text,
      hasImage: Boolean(source.imageBase64),
    });
  }
  const { data, error } = await supabase!.functions.invoke("import-recipe", {
    body: {
      url: source.url,
      text: source.text,
      image_base64: source.imageBase64,
      mime_type: source.mimeType,
    },
  });
  if (error) throw new Error(error.message ?? "Import failed");
  if (data?.error) throw new Error(data.error);
  return data.recipe as Recipe;
}

export async function generateRecipe(
  prompt: string,
  servings?: number,
): Promise<Recipe> {
  if (isDemo) return demoGenerate(prompt, servings);
  const { data, error } = await supabase!.functions.invoke("generate-recipe", {
    body: { prompt, servings },
  });
  if (error) throw new Error(error.message ?? "Generation failed");
  if (data?.error) throw new Error(data.error);
  return data.recipe as Recipe;
}
