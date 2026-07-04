import { scaleQuantity } from "./quantity";
import type {
  AppNotification,
  Comment,
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

const chefs: Record<string, Pick<Profile, "id" | "username" | "avatar_url">> = {
  mika: { id: "chef-mika", username: "mika.eats", avatar_url: null },
  theo: { id: "chef-theo", username: "theo_cooks", avatar_url: null },
  june: { id: "chef-june", username: "june.bakes", avatar_url: null },
  rafa: { id: "chef-rafa", username: "rafa.fuego", avatar_url: null },
};

function daysAgo(n: number): string {
  return new Date(Date.now() - n * 86_400_000).toISOString();
}

const SEED_RECIPES: Recipe[] = [
  {
    id: "seed-miso-salmon",
    author_id: chefs.mika.id,
    author: chefs.mika,
    title: "Caramelized Miso Salmon Bowl",
    description:
      "Silky salmon lacquered in sweet-savory miso glaze over sushi rice with quick-pickled cucumber. Weeknight fancy in 25 minutes.",
    emoji: "🍣",
    cuisine: "Japanese",
    difficulty: "Easy",
    prep_time_minutes: 10,
    cook_time_minutes: 15,
    servings: 2,
    calories: 560,
    protein_g: 38,
    carbs_g: 52,
    fat_g: 21,
    tags: ["High-protein", "Pescatarian", "Weeknight"],
    ingredients: [
      { item: "Salmon fillets", quantity: "2 × 150 g (5 oz)", note: "skin on" },
      { item: "White miso paste", quantity: "2 tbsp" },
      { item: "Maple syrup", quantity: "1 tbsp" },
      { item: "Soy sauce", quantity: "1 tbsp" },
      { item: "Rice vinegar", quantity: "2 tbsp" },
      { item: "Sushi rice", quantity: "150 g (¾ cup)", note: "rinsed" },
      { item: "Persian cucumber", quantity: "1", note: "ribboned" },
      { item: "Scallions + sesame", quantity: "to finish" },
    ],
    steps: [
      { step: 1, instruction: "Cook the rice. While it steams, whisk miso, maple, soy and 1 tbsp water into a glossy glaze." },
      { step: 2, instruction: "Toss cucumber ribbons with rice vinegar and a pinch of salt. Set aside to pickle.", tip: "A pinch of sugar rounds out the pickle." },
      { step: 3, instruction: "Sear salmon skin-side down 4 minutes in a hot pan. Flip, brush thickly with glaze, cook 3 more minutes." },
      { step: 4, instruction: "Broil 90 seconds until the glaze bubbles and caramelizes at the edges.", tip: "Watch closely — miso goes from bronzed to burnt fast." },
      { step: 5, instruction: "Build bowls: rice, salmon, drained pickles. Shower with scallions and sesame." },
    ],
    source_prompt: "quick high-protein salmon dinner",
    net_upvotes: 482,
    cook_count: 214,
    comment_count: 3,
    created_at: daysAgo(6),
  },
  {
    id: "seed-chickpea-curry",
    author_id: chefs.theo.id,
    author: chefs.theo,
    title: "20-Minute Coconut Chickpea Curry",
    description:
      "Creamy, gently spiced and entirely from the pantry. The crispy chickpea topping is the move.",
    emoji: "🍛",
    cuisine: "Indian-ish",
    difficulty: "Easy",
    prep_time_minutes: 5,
    cook_time_minutes: 15,
    servings: 4,
    calories: 430,
    protein_g: 16,
    carbs_g: 48,
    fat_g: 22,
    tags: ["Vegan", "Pantry", "One-pan", "Gluten-free"],
    ingredients: [
      { item: "Chickpeas", quantity: "2 cans (800 g)", note: "drained, ½ cup reserved" },
      { item: "Coconut milk", quantity: "1 can (400 ml)", note: "full fat" },
      { item: "Crushed tomatoes", quantity: "200 g (1 cup)" },
      { item: "Yellow onion", quantity: "1", note: "diced" },
      { item: "Garlic + ginger", quantity: "3 cloves + 1 inch", note: "grated" },
      { item: "Curry powder", quantity: "2 tbsp" },
      { item: "Baby spinach", quantity: "2 big handfuls" },
    ],
    steps: [
      { step: 1, instruction: "Crisp the reserved chickpeas in olive oil with a pinch of curry powder and salt. Set aside." },
      { step: 2, instruction: "In the same pan, soften onion 3 minutes. Add garlic, ginger and curry powder; bloom 60 seconds.", tip: "Toasting spices in oil unlocks their flavor." },
      { step: 3, instruction: "Add tomatoes, coconut milk and chickpeas. Simmer 8 minutes until it thickens slightly." },
      { step: 4, instruction: "Wilt in the spinach, season with salt and a squeeze of lime. Top with crispy chickpeas." },
    ],
    source_prompt: "vegan pantry curry in 20 minutes",
    net_upvotes: 391,
    cook_count: 178,
    comment_count: 2,
    created_at: daysAgo(4),
  },
  {
    id: "seed-smash-tacos",
    author_id: chefs.rafa.id,
    author: chefs.rafa,
    title: "Crispy Smash Burger Tacos",
    description:
      "A smash patty seared directly onto a tortilla — burger flavor, taco format, ridiculous crust.",
    emoji: "🌮",
    cuisine: "Tex-Mex",
    difficulty: "Medium",
    prep_time_minutes: 15,
    cook_time_minutes: 10,
    servings: 4,
    calories: 610,
    protein_g: 33,
    carbs_g: 38,
    fat_g: 34,
    tags: ["Crowd-pleaser", "30-minute", "Beef"],
    ingredients: [
      { item: "Ground beef (80/20)", quantity: "500 g (1 lb)" },
      { item: "Small flour tortillas", quantity: "8" },
      { item: "American cheese", quantity: "8 slices" },
      { item: "White onion", quantity: "½", note: "shaved paper-thin" },
      { item: "Shredded lettuce", quantity: "2 cups" },
      { item: "Mayo + ketchup + pickle brine", quantity: "¼ cup + 2 tbsp + 1 tbsp", note: "burger sauce" },
    ],
    steps: [
      { step: 1, instruction: "Stir the burger sauce together. Divide beef into 8 loose 60 g balls — don't compact them." },
      { step: 2, instruction: "Press a beef ball thinly onto each tortilla so it reaches the edges." },
      { step: 3, instruction: "Sear beef-side down in a screaming hot pan, pressing firmly, 2–3 minutes until deeply crusted.", tip: "A second pan on top makes a great press." },
      { step: 4, instruction: "Flip, add cheese and onion, cook 1 minute until the tortilla crisps." },
      { step: 5, instruction: "Fold, stuff with lettuce and sauce, eat immediately over the sink." },
    ],
    source_prompt: "smash burger tacos for four",
    net_upvotes: 357,
    cook_count: 342,
    comment_count: 2,
    created_at: daysAgo(2),
  },
  {
    id: "seed-lemon-pasta",
    author_id: chefs.june.id,
    author: chefs.june,
    title: "One-Pot Lemon Ricotta Rigatoni",
    description:
      "Bright, creamy and done before the table is set. The pasta water does all the sauce work.",
    emoji: "🍋",
    cuisine: "Italian",
    difficulty: "Easy",
    prep_time_minutes: 5,
    cook_time_minutes: 15,
    servings: 3,
    calories: 520,
    protein_g: 21,
    carbs_g: 68,
    fat_g: 18,
    tags: ["Vegetarian", "One-pot", "15-minute"],
    ingredients: [
      { item: "Rigatoni", quantity: "300 g (10 oz)" },
      { item: "Whole-milk ricotta", quantity: "250 g (1 cup)" },
      { item: "Lemon", quantity: "1", note: "zest + juice" },
      { item: "Parmesan", quantity: "40 g (½ cup)", note: "finely grated" },
      { item: "Black pepper", quantity: "lots" },
      { item: "Basil", quantity: "a handful" },
    ],
    steps: [
      { step: 1, instruction: "Boil rigatoni in well-salted water until just shy of al dente. Reserve 1 cup of pasta water." },
      { step: 2, instruction: "Whisk ricotta, parmesan, lemon zest and juice with ½ cup pasta water into a silky sauce." },
      { step: 3, instruction: "Toss pasta with the sauce off-heat, loosening with more pasta water until it coats every tube.", tip: "Off-heat keeps the ricotta creamy instead of grainy." },
      { step: 4, instruction: "Finish with basil, black pepper and a drizzle of good olive oil." },
    ],
    source_prompt: "easy vegetarian pasta with lemon",
    net_upvotes: 289,
    cook_count: 96,
    comment_count: 1,
    created_at: daysAgo(1),
  },
  {
    id: "seed-breakfast-tacos",
    author_id: chefs.mika.id,
    author: chefs.mika,
    title: "5-Minute Protein Breakfast Wrap",
    description:
      "Soft scramble, crispy cheese skirt, one pan, five minutes. 38 g of protein before your coffee cools.",
    emoji: "🌯",
    cuisine: "American",
    difficulty: "Easy",
    prep_time_minutes: 2,
    cook_time_minutes: 3,
    servings: 1,
    calories: 520,
    protein_g: 38,
    carbs_g: 28,
    fat_g: 24,
    tags: ["High-protein", "Breakfast", "5-minute"],
    ingredients: [
      { item: "Eggs", quantity: "3" },
      { item: "Cottage cheese", quantity: "2 tbsp", note: "trust the process" },
      { item: "Large tortilla", quantity: "1" },
      { item: "Cheddar", quantity: "30 g (⅓ cup)", note: "shredded" },
      { item: "Hot sauce", quantity: "to taste" },
    ],
    steps: [
      { step: 1, instruction: "Whisk eggs with cottage cheese and a pinch of salt. Soft-scramble over medium-low, stopping while glossy." },
      { step: 2, instruction: "Push eggs aside, scatter cheddar in the pan, and lay the tortilla on top. 60 seconds makes a crispy cheese skirt.", tip: "The cheese glues the wrap shut." },
      { step: 3, instruction: "Flip the tortilla cheese-side up, pile on eggs and hot sauce, roll tightly and sear the seam." },
    ],
    source_prompt: "fast high protein breakfast",
    net_upvotes: 214,
    cook_count: 511,
    comment_count: 1,
    created_at: daysAgo(0.5),
  },
  {
    id: "seed-mushroom-ramen",
    author_id: chefs.theo.id,
    author: chefs.theo,
    title: "Midnight Garlic Butter Mushroom Ramen",
    description:
      "Instant noodles glow-up: umami-bomb broth, jammy egg, torched mushrooms. Better than the shop, cheaper than delivery.",
    emoji: "🍜",
    cuisine: "Japanese-ish",
    difficulty: "Medium",
    prep_time_minutes: 10,
    cook_time_minutes: 40,
    servings: 2,
    calories: 540,
    protein_g: 19,
    carbs_g: 58,
    fat_g: 26,
    tags: ["Vegetarian", "Comfort", "Late-night"],
    ingredients: [
      { item: "Instant ramen", quantity: "2 packs", note: "noodles only" },
      { item: "Mixed mushrooms", quantity: "300 g (10 oz)", note: "torn" },
      { item: "Butter", quantity: "3 tbsp" },
      { item: "Garlic", quantity: "4 cloves", note: "sliced" },
      { item: "White miso", quantity: "1 tbsp" },
      { item: "Soy sauce", quantity: "2 tbsp" },
      { item: "Eggs", quantity: "2", note: "jammy-boiled 6:30" },
      { item: "Chili crisp", quantity: "to finish" },
    ],
    steps: [
      { step: 1, instruction: "Boil eggs 6½ minutes, then ice bath. Peel when cool." },
      { step: 2, instruction: "Sear mushrooms dry in a hot pan until deeply browned, then add butter and garlic and baste 2 minutes.", tip: "Dry pan first = maximum browning, zero sog." },
      { step: 3, instruction: "Whisk miso and soy into 700 ml hot water. Simmer half the mushrooms in it 5 minutes." },
      { step: 4, instruction: "Cook noodles in the broth 2 minutes. Bowl up with remaining mushrooms, halved eggs and chili crisp." },
    ],
    source_prompt: "fancy instant ramen with mushrooms",
    net_upvotes: 176,
    cook_count: 88,
    comment_count: 1,
    created_at: daysAgo(0.2),
  },
];

const SEED_COMMENTS: Comment[] = [
  {
    id: "c-1",
    recipe_id: "seed-miso-salmon",
    user_id: chefs.theo.id,
    author: chefs.theo,
    body: "Made this twice this week. The broil step is not optional — that caramelized edge is everything.",
    created_at: daysAgo(4),
  },
  {
    id: "c-2",
    recipe_id: "seed-miso-salmon",
    user_id: chefs.june.id,
    author: chefs.june,
    body: "Swapped maple for honey and it worked great. 10/10 weeknight dinner.",
    created_at: daysAgo(3),
  },
  {
    id: "c-3",
    recipe_id: "seed-miso-salmon",
    user_id: chefs.rafa.id,
    author: chefs.rafa,
    body: "Remixed this with gochujang instead of miso 🔥 highly recommend.",
    created_at: daysAgo(1),
  },
  {
    id: "c-4",
    recipe_id: "seed-chickpea-curry",
    user_id: chefs.mika.id,
    author: chefs.mika,
    body: "The crispy chickpea topping is genius. Doubled it, no regrets.",
    created_at: daysAgo(2),
  },
  {
    id: "c-5",
    recipe_id: "seed-chickpea-curry",
    user_id: chefs.june.id,
    author: chefs.june,
    body: "Used frozen spinach and it was still fantastic. True pantry hero.",
    created_at: daysAgo(1),
  },
  {
    id: "c-6",
    recipe_id: "seed-smash-tacos",
    user_id: chefs.mika.id,
    author: chefs.mika,
    body: "\"Eat immediately over the sink\" — accurate. Family demolished these.",
    created_at: daysAgo(1),
  },
  {
    id: "c-7",
    recipe_id: "seed-smash-tacos",
    user_id: chefs.theo.id,
    author: chefs.theo,
    body: "Cast iron + a bacon press = perfect crust every time.",
    created_at: daysAgo(0.5),
  },
  {
    id: "c-8",
    recipe_id: "seed-lemon-pasta",
    user_id: chefs.rafa.id,
    author: chefs.rafa,
    body: "Off-heat tip saved me — first attempt on heat went grainy, second was silk.",
    created_at: daysAgo(0.4),
  },
  {
    id: "c-9",
    recipe_id: "seed-breakfast-tacos",
    user_id: chefs.june.id,
    author: chefs.june,
    body: "The cottage cheese thing sounded wrong. It is extremely right.",
    created_at: daysAgo(0.3),
  },
  {
    id: "c-10",
    recipe_id: "seed-mushroom-ramen",
    user_id: chefs.mika.id,
    author: chefs.mika,
    body: "Dry-pan mushroom sear is a game changer. Never crowding the pan again.",
    created_at: daysAgo(0.1),
  },
];

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

const KEY = "adaptable.demo.v5";

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
  actor: (typeof chefs)[keyof typeof chefs],
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
  setTimeout(() => pushDemoNotification("vote", chefs.rafa, recipe), 7_000);
  setTimeout(() => pushDemoNotification("comment", chefs.mika, recipe), 16_000);
  setTimeout(() => pushDemoNotification("cook", chefs.theo, recipe), 28_000);
  setTimeout(() => pushDemoNotification("vote", chefs.june, recipe), 40_000);
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
