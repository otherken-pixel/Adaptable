import { scaleQuantity } from "./quantity";
import seedRecipesJson from "../../shared/seed-recipes.json";
import type {
  AppNotification,
  Comment,
  Difficulty,
  MealPlanEntry,
  Preferences,
  Profile,
  Recipe,
  VoteValue,
} from "./types";

/**
 * Demo Mode backend — a seeded, localStorage-persisted store used when
 * Supabase env vars are absent. Lets anyone run the full product loop
 * (generate → render → vote → save) with zero configuration.
 */

export const DEMO_USER: Profile = {
  id: "demo-user",
  username: "you",
  avatar_url: null,
  created_at: new Date().toISOString(),
};

/**
 * All 30 seed recipes (and their review comments) are authored once in
 * shared/seed-recipes.json — the same file that generates the live
 * Supabase seed migration (see scripts/generate-seed-sql.py) — so Demo
 * Mode and the live backend always show identical content.
 */
interface SeedIngredientJSON {
  item: string;
  quantity: string;
  note?: string;
}
interface SeedStepJSON {
  step: number;
  instruction: string;
  tip?: string;
}
interface SeedCommentJSON {
  author: string;
  body: string;
}
interface SeedRecipeJSON {
  id: string;
  author: string;
  title: string;
  description: string;
  emoji: string;
  cuisine: string;
  difficulty: Difficulty;
  prep_time_minutes: number;
  cook_time_minutes: number;
  servings: number;
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  tags: string[];
  ingredients: SeedIngredientJSON[];
  steps: SeedStepJSON[];
  source_prompt: string;
  net_upvotes: number;
  cook_count: number;
  comment_count: number;
  days_ago: number;
  comments: SeedCommentJSON[];
}
interface SeedDataJSON {
  chefs: Array<{ username: string; existing: boolean }>;
  recipes: SeedRecipeJSON[];
}

const seedData = seedRecipesJson as SeedDataJSON;

// Stable ids matching the ones this file has always used, so returning
// Demo Mode users' localStorage (keyed on these ids) stays valid.
const CHEF_ID_OVERRIDES: Record<string, string> = {
  "mika.eats": "chef-mika",
  theo_cooks: "chef-theo",
  "june.bakes": "chef-june",
  "rafa.fuego": "chef-rafa",
};

function chefIdFor(username: string): string {
  return CHEF_ID_OVERRIDES[username] ?? `chef-${username.replace(/[^a-z0-9]/gi, "")}`;
}

/** Full-username-keyed chef directory, built from shared/seed-recipes.json. */
const chefsByUsername: Record<string, Pick<Profile, "id" | "username" | "avatar_url">> =
  Object.fromEntries(
    seedData.chefs.map((c) => [
      c.username,
      { id: chefIdFor(c.username), username: c.username, avatar_url: null },
    ]),
  );

function daysAgo(n: number): string {
  return new Date(Date.now() - n * 86_400_000).toISOString();
}

const SEED_RECIPES: Recipe[] = seedData.recipes.map((r) => {
  const author = chefsByUsername[r.author];
  return {
    id: r.id,
    author_id: author.id,
    author,
    title: r.title,
    description: r.description,
    emoji: r.emoji,
    cuisine: r.cuisine,
    difficulty: r.difficulty,
    prep_time_minutes: r.prep_time_minutes,
    cook_time_minutes: r.cook_time_minutes,
    servings: r.servings,
    calories: r.calories,
    protein_g: r.protein_g,
    carbs_g: r.carbs_g,
    fat_g: r.fat_g,
    tags: r.tags,
    ingredients: r.ingredients,
    steps: r.steps,
    source_prompt: r.source_prompt,
    net_upvotes: r.net_upvotes,
    cook_count: r.cook_count,
    comment_count: r.comment_count,
    created_at: daysAgo(r.days_ago),
  };
});

// Comments are staggered between the recipe's creation and now (25/50/75%
// of the way through), matching the fractions used by the live-DB seed.
const SEED_COMMENTS: Comment[] = seedData.recipes.flatMap((r) =>
  r.comments.map((c, i): Comment => {
    const author = chefsByUsername[c.author];
    const frac = (i + 1) / (r.comments.length + 1);
    return {
      id: `c-seed-${r.id}-${i}`,
      recipe_id: r.id,
      user_id: author.id,
      author,
      body: c.body,
      created_at: daysAgo(r.days_ago * (1 - frac)),
    };
  }),
);

interface DemoState {
  recipes: Recipe[];
  votes: Record<string, VoteValue>;
  saves: string[];
  comments: Comment[];
  notifications: AppNotification[];
  plans: MealPlanEntry[];
  preferences: Preferences;
  follows: string[];
}

/** Change events so live UI (inbox badge, feed) can react to the store. */
const listeners = new Set<() => void>();

export function subscribeDemoStore(fn: () => void): () => void {
  listeners.add(fn);
  return () => {
    listeners.delete(fn);
  };
}

const KEY = "adaptable.demo.v6";

function load(): DemoState {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) return JSON.parse(raw) as DemoState;
  } catch {
    /* corrupted state — reseed */
  }
  return {
    recipes: SEED_RECIPES,
    votes: {},
    saves: [],
    comments: SEED_COMMENTS,
    notifications: [],
    plans: [],
    preferences: {},
    follows: [],
  };
}

let state: DemoState = load();

function persist() {
  try {
    localStorage.setItem(KEY, JSON.stringify(state));
  } catch {
    /* storage full/unavailable — demo continues in memory */
  }
  for (const fn of listeners) fn();
}

export const demoStore = {
  listRecipes(): Recipe[] {
    return [...state.recipes];
  },
  getRecipe(id: string): Recipe | undefined {
    return state.recipes.find((r) => r.id === id);
  },
  addRecipe(recipe: Recipe) {
    state.recipes = [recipe, ...state.recipes];
    persist();
  },
  getVotes(): Record<string, VoteValue> {
    return { ...state.votes };
  },
  setVote(recipeId: string, value: VoteValue | null) {
    const prev = state.votes[recipeId] ?? 0;
    const next = value ?? 0;
    if (value === null) delete state.votes[recipeId];
    else state.votes[recipeId] = value;
    state.recipes = state.recipes.map((r) =>
      r.id === recipeId ? { ...r, net_upvotes: r.net_upvotes - prev + next } : r,
    );
    persist();
  },
  getSaves(): string[] {
    return [...state.saves];
  },
  toggleSave(recipeId: string): boolean {
    const saved = state.saves.includes(recipeId);
    state.saves = saved
      ? state.saves.filter((id) => id !== recipeId)
      : [recipeId, ...state.saves];
    persist();
    return !saved;
  },
  listComments(recipeId: string): Comment[] {
    return state.comments
      .filter((c) => c.recipe_id === recipeId)
      .sort((a, b) => b.created_at.localeCompare(a.created_at));
  },
  addComment(recipeId: string, body: string): Comment {
    const comment: Comment = {
      id: `c-${Date.now()}`,
      recipe_id: recipeId,
      user_id: DEMO_USER.id,
      author: { id: DEMO_USER.id, username: DEMO_USER.username, avatar_url: null },
      body,
      created_at: new Date().toISOString(),
    };
    state.comments = [comment, ...state.comments];
    state.recipes = state.recipes.map((r) =>
      r.id === recipeId ? { ...r, comment_count: r.comment_count + 1 } : r,
    );
    persist();
    return comment;
  },
  deleteComment(commentId: string) {
    const target = state.comments.find((c) => c.id === commentId);
    if (!target) return;
    state.comments = state.comments.filter((c) => c.id !== commentId);
    state.recipes = state.recipes.map((r) =>
      r.id === target.recipe_id
        ? { ...r, comment_count: Math.max(0, r.comment_count - 1) }
        : r,
    );
    persist();
  },
  recordCook(recipeId: string) {
    state.recipes = state.recipes.map((r) =>
      r.id === recipeId ? { ...r, cook_count: r.cook_count + 1 } : r,
    );
    persist();
  },
  listPlans(): MealPlanEntry[] {
    return state.plans.map((p) => ({
      ...p,
      recipe: state.recipes.find((r) => r.id === p.recipe_id) ?? null,
    }));
  },
  addPlan(recipeId: string, planDate: string, servings: number): MealPlanEntry {
    const entry: MealPlanEntry = {
      id: `p-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
      user_id: DEMO_USER.id,
      recipe_id: recipeId,
      plan_date: planDate,
      servings,
      created_at: new Date().toISOString(),
    };
    state.plans = [...state.plans, entry];
    persist();
    return entry;
  },
  updatePlanServings(id: string, servings: number) {
    state.plans = state.plans.map((p) => (p.id === id ? { ...p, servings } : p));
    persist();
  },
  removePlan(id: string) {
    state.plans = state.plans.filter((p) => p.id !== id);
    persist();
  },
  getPreferences(): Preferences {
    return { ...state.preferences };
  },
  setPreferences(prefs: Preferences) {
    state.preferences = { ...prefs };
    persist();
  },
  getFollows(): string[] {
    return [...state.follows];
  },
  toggleFollow(chefId: string): boolean {
    const following = state.follows.includes(chefId);
    state.follows = following
      ? state.follows.filter((id) => id !== chefId)
      : [...state.follows, chefId];
    persist();
    return !following;
  },
  listNotifications(): AppNotification[] {
    return [...state.notifications].sort((a, b) =>
      b.created_at.localeCompare(a.created_at),
    );
  },
  markNotificationsRead() {
    state.notifications = state.notifications.map((n) => ({ ...n, read: true }));
    persist();
  },
};

/* ---- Simulated community engagement (Demo Mode only) ----
   A minute after you publish, demo chefs start reacting so the
   notification inbox and trending signals come alive. */

function pushDemoNotification(
  type: AppNotification["type"],
  actor: Pick<Profile, "id" | "username" | "avatar_url">,
  recipe: Recipe,
) {
  const current = state.recipes.find((r) => r.id === recipe.id);
  if (!current) return;
  const notification: AppNotification = {
    id: `n-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
    user_id: DEMO_USER.id,
    actor_id: actor.id,
    actor,
    recipe_id: recipe.id,
    recipe: { id: recipe.id, title: recipe.title, emoji: recipe.emoji },
    type,
    read: false,
    created_at: new Date().toISOString(),
  };
  state.notifications = [notification, ...state.notifications];

  if (type === "vote") {
    state.recipes = state.recipes.map((r) =>
      r.id === recipe.id ? { ...r, net_upvotes: r.net_upvotes + 1 } : r,
    );
  } else if (type === "cook") {
    state.recipes = state.recipes.map((r) =>
      r.id === recipe.id ? { ...r, cook_count: r.cook_count + 1 } : r,
    );
  } else if (type === "comment") {
    state.comments = [
      {
        id: `c-${Date.now()}`,
        recipe_id: recipe.id,
        user_id: actor.id,
        author: actor,
        body: "Made this from your post — turned out fantastic. Instant save! 🔥",
        created_at: new Date().toISOString(),
      },
      ...state.comments,
    ];
    state.recipes = state.recipes.map((r) =>
      r.id === recipe.id ? { ...r, comment_count: r.comment_count + 1 } : r,
    );
  }
  persist();
}

function simulateEngagement(recipe: Recipe) {
  setTimeout(() => pushDemoNotification("vote", chefsByUsername["rafa.fuego"], recipe), 7_000);
  setTimeout(() => pushDemoNotification("comment", chefsByUsername["mika.eats"], recipe), 16_000);
  setTimeout(() => pushDemoNotification("cook", chefsByUsername["theo_cooks"], recipe), 28_000);
  setTimeout(() => pushDemoNotification("vote", chefsByUsername["june.bakes"], recipe), 40_000);
}

/* ---- Demo recipe generation (no API key required) ---- */

const DEMO_TEMPLATES: Array<
  Omit<
    Recipe,
    | "id"
    | "author_id"
    | "author"
    | "source_prompt"
    | "net_upvotes"
    | "cook_count"
    | "comment_count"
    | "created_at"
  >
> = [
  {
    title: "Charred Corn & Halloumi Grain Bowl",
    description:
      "Squeaky golden halloumi, blistered corn and a lime-honey dressing over herby grains — built from your request.",
    emoji: "🥗",
    cuisine: "Mediterranean",
    difficulty: "Easy",
    prep_time_minutes: 10,
    cook_time_minutes: 12,
    servings: 2,
    calories: 490,
    protein_g: 22,
    carbs_g: 45,
    fat_g: 24,
    tags: ["Vegetarian", "Meal-prep", "Fresh"],
    ingredients: [
      { item: "Halloumi", quantity: "200 g (7 oz)", note: "thick slices" },
      { item: "Corn", quantity: "2 cobs", note: "kernels removed" },
      { item: "Cooked farro or quinoa", quantity: "2 cups" },
      { item: "Lime", quantity: "1", note: "juiced" },
      { item: "Honey", quantity: "1 tsp" },
      { item: "Mint + parsley", quantity: "a big handful", note: "chopped" },
    ],
    steps: [
      { step: 1, instruction: "Char corn kernels in a dry hot pan 4 minutes until spotted black. Remove." },
      { step: 2, instruction: "Sear halloumi slices 2 minutes per side until deeply golden.", tip: "No oil needed — halloumi releases its own." },
      { step: 3, instruction: "Whisk lime juice, honey, 2 tbsp olive oil and a pinch of salt." },
      { step: 4, instruction: "Toss grains with herbs and half the dressing; top with corn, halloumi and the rest." },
    ],
  },
  {
    title: "Sticky Gochujang Meatballs",
    description:
      "Glazed, gingery and gone in minutes. Serve over rice with quick-pickled cucumbers.",
    emoji: "🍢",
    cuisine: "Korean-inspired",
    difficulty: "Medium",
    prep_time_minutes: 15,
    cook_time_minutes: 15,
    servings: 4,
    calories: 520,
    protein_g: 34,
    carbs_g: 42,
    fat_g: 20,
    tags: ["High-protein", "Sweet & spicy", "Weeknight"],
    ingredients: [
      { item: "Ground chicken or pork", quantity: "500 g (1 lb)" },
      { item: "Panko", quantity: "½ cup" },
      { item: "Egg", quantity: "1" },
      { item: "Scallions", quantity: "4", note: "minced, whites and greens separated" },
      { item: "Gochujang", quantity: "3 tbsp" },
      { item: "Honey + soy + rice vinegar", quantity: "2 tbsp each" },
      { item: "Garlic + ginger", quantity: "2 cloves + 1 inch", note: "grated" },
    ],
    steps: [
      { step: 1, instruction: "Mix meat, panko, egg, scallion whites, half the garlic-ginger and a pinch of salt. Roll into 16 balls." },
      { step: 2, instruction: "Sear meatballs in a wide pan until browned all over, about 6 minutes." },
      { step: 3, instruction: "Whisk gochujang, honey, soy, vinegar and remaining garlic-ginger with ¼ cup water; pour over and simmer 6 minutes until sticky.", tip: "The glaze should coat the back of a spoon." },
      { step: 4, instruction: "Shower with scallion greens and sesame. Serve over rice." },
    ],
  },
  {
    title: "Crispy Gnocchi with Burst Tomatoes",
    description:
      "Shelf-stable gnocchi pan-fried until golden, tossed with jammy burst tomatoes and torn mozzarella.",
    emoji: "🍅",
    cuisine: "Italian",
    difficulty: "Easy",
    prep_time_minutes: 5,
    cook_time_minutes: 15,
    servings: 2,
    calories: 540,
    protein_g: 18,
    carbs_g: 62,
    fat_g: 22,
    tags: ["Vegetarian", "One-pan", "20-minute"],
    ingredients: [
      { item: "Shelf-stable gnocchi", quantity: "500 g (1 lb)" },
      { item: "Cherry tomatoes", quantity: "300 g (2 cups)" },
      { item: "Garlic", quantity: "3 cloves", note: "sliced" },
      { item: "Fresh mozzarella", quantity: "125 g (1 ball)", note: "torn" },
      { item: "Basil", quantity: "a handful" },
      { item: "Chili flakes", quantity: "a pinch" },
    ],
    steps: [
      { step: 1, instruction: "Pan-fry gnocchi in olive oil, untouched, 3 minutes per side until golden and crisp. Remove.", tip: "Don't boil them — straight into the pan." },
      { step: 2, instruction: "Add tomatoes, garlic and chili to the pan; cook until tomatoes burst and go jammy, 6 minutes." },
      { step: 3, instruction: "Crush a few tomatoes, return gnocchi, toss to coat." },
      { step: 4, instruction: "Off heat, tuck in mozzarella and basil. Season and serve from the pan." },
    ],
  },
];

let demoGenCount = 0;

/** Fakes the Gemini call in Demo Mode with believable latency + output. */
export async function demoGenerate(
  prompt: string,
  servings?: number,
): Promise<Recipe> {
  await new Promise((r) => setTimeout(r, 2600 + Math.random() * 1200));
  const template = DEMO_TEMPLATES[demoGenCount++ % DEMO_TEMPLATES.length];
  // Honor the requested party size, scaling template quantities to match.
  const targetServings =
    servings && servings >= 1 && servings <= 12 ? servings : template.servings;
  const factor = targetServings / template.servings;
  const recipe: Recipe = {
    ...template,
    servings: targetServings,
    ingredients:
      factor === 1
        ? template.ingredients
        : template.ingredients.map((ing) => ({
            ...ing,
            quantity: scaleQuantity(ing.quantity, factor),
          })),
    id: `gen-${Date.now()}`,
    author_id: DEMO_USER.id,
    author: { id: DEMO_USER.id, username: DEMO_USER.username, avatar_url: null },
    source_prompt: prompt,
    net_upvotes: 0,
    cook_count: 0,
    comment_count: 0,
    created_at: new Date().toISOString(),
  };
  demoStore.addRecipe(recipe);
  simulateEngagement(recipe);
  return recipe;
}

/** Fakes recipe import in Demo Mode (live mode parses the real source). */
export async function demoImport(source: {
  url?: string;
  text?: string;
  hasImage?: boolean;
}): Promise<Recipe> {
  await new Promise((r) => setTimeout(r, 2200 + Math.random() * 900));
  const template = DEMO_TEMPLATES[demoGenCount++ % DEMO_TEMPLATES.length];
  const recipe: Recipe = {
    ...template,
    id: `imp-${Date.now()}`,
    author_id: DEMO_USER.id,
    author: { id: DEMO_USER.id, username: DEMO_USER.username, avatar_url: null },
    source_prompt: "",
    source_url: source.url ?? null,
    net_upvotes: 0,
    cook_count: 0,
    comment_count: 0,
    created_at: new Date().toISOString(),
  };
  demoStore.addRecipe(recipe);
  return recipe;
}
