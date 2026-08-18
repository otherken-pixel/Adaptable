/** Rows and shared shapes for the Supabase schema + Gemini output. */

/** Taste profile stored in profiles.preferences (jsonb). */
export interface Preferences {
  diets?: string[];
  allergies?: string[];
  dislikes?: string[];
  household_size?: number;
  spice?: "Mild" | "Medium" | "Hot";
  skill?: "Beginner" | "Confident" | "Pro";
}

export interface Profile {
  id: string;
  username: string;
  avatar_url: string | null;
  preferences?: Preferences;
  created_at: string;
}

export type Difficulty = "Easy" | "Medium" | "Hard";

/** One entry of recipes.ingredients (jsonb). */
export interface Ingredient {
  item: string;
  quantity: string;
  note?: string;
}

/** One entry of recipes.steps (jsonb). */
export interface RecipeStep {
  step: number;
  instruction: string;
  tip?: string;
  /** Ingredient `item` names used in this step. */
  ingredients_used?: string[];
  /** Every timer in this step, in seconds. */
  duration_seconds?: number[];
  /** Heat setting when this step sets it, e.g. "400°F (200°C)". */
  temperature?: string;
  equipment?: string[];
  /** Doneness cue, e.g. "tomatoes burst, feta golden". */
  look_for?: string;
}

export interface Recipe {
  id: string;
  author_id: string;
  title: string;
  description: string;
  emoji: string;
  cuisine: string;
  difficulty: Difficulty;
  prep_time_minutes: number;
  cook_time_minutes: number;
  servings: number;
  calories: number | null;
  protein_g: number | null;
  carbs_g: number | null;
  fat_g: number | null;
  tags: string[];
  ingredients: Ingredient[];
  steps: RecipeStep[];
  source_prompt: string;
  /** Set when the recipe was imported rather than generated. */
  source_url?: string | null;
  /** AI-generated dish photo (public URL); null → emoji/gradient fallback. */
  image_url?: string | null;
  /** Curated Discover pick for empty Following / social states. */
  featured?: boolean;
  /** Canonical staple-stripped ingredient tokens (meal-prep overlap). */
  ingredient_keys?: string[];
  primary_method?: string | null;
  base_protein?: string | null;
  meal_slot?: string | null;
  active_prep_minutes?: number | null;
  equipment?: string[];
  net_upvotes: number;
  /** Completed Cook Mode sessions — the strongest trending signal. */
  cook_count: number;
  comment_count: number;
  created_at: string;
  /** Joined author profile (select `author:profiles(...)`). */
  author?: Pick<Profile, "id" | "username" | "avatar_url"> | null;
}

export interface Comment {
  id: string;
  recipe_id: string;
  user_id: string;
  body: string;
  created_at: string;
  author?: Pick<Profile, "id" | "username" | "avatar_url"> | null;
}

export type VoteValue = 1 | -1;

export type FeedSort = "hot" | "top" | "new";

/** One planned meal (meal_plans table / local store in Demo Mode). */
export interface MealPlanEntry {
  id: string;
  user_id: string;
  recipe_id: string;
  /** ISO date (yyyy-mm-dd). */
  plan_date: string;
  servings: number;
  created_at: string;
  recipe?: Recipe | null;
}

/** A community "I cooked it" photo. */
export interface RecipePhoto {
  id: string;
  recipe_id: string;
  user_id: string;
  path: string;
  created_at: string;
  /** Public URL resolved from storage. */
  url?: string;
}

export type NotificationType = "vote" | "comment" | "cook";

/** In-app notification (notifications table / local store in Demo Mode). */
export interface AppNotification {
  id: string;
  /** Recipient. */
  user_id: string;
  actor_id: string | null;
  recipe_id: string | null;
  type: NotificationType;
  read: boolean;
  created_at: string;
  actor?: Pick<Profile, "id" | "username" | "avatar_url"> | null;
  recipe?: Pick<Recipe, "id" | "title" | "emoji"> | null;
}

/** One grocery row (shopping_items table / local store in Demo Mode). */
export interface ShoppingItem {
  id: string;
  recipe_id: string | null;
  recipe_title: string;
  item: string;
  quantity: string;
  checked: boolean;
  created_at: string;
}

/** Shape the Gemini edge function is asked to produce (before insert). */
export interface GeneratedRecipe {
  title: string;
  description: string;
  emoji: string;
  cuisine: string;
  difficulty: Difficulty;
  prep_time_minutes: number;
  cook_time_minutes: number;
  servings: number;
  calories?: number;
  tags: string[];
  ingredients: Ingredient[];
  steps: RecipeStep[];
}
