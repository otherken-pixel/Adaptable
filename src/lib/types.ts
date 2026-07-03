/** Rows and shared shapes for the Supabase schema + Gemini output. */

export interface Profile {
  id: string;
  username: string;
  avatar_url: string | null;
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
  tags: string[];
  ingredients: Ingredient[];
  steps: RecipeStep[];
  source_prompt: string;
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
