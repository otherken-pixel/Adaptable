/**
 * Lightweight pure-function smoke tests (no build step).
 * Run: node scripts/smoke-tests.mjs
 */

import assert from "node:assert/strict";
import { groceryAisle, sortAisles } from "../src/lib/aisle.ts";
import { mergeQuantities, normalizeGroceryKey } from "../src/lib/groceryMerge.ts";
import { recipeMayContainAllergens } from "../src/lib/allergy.ts";
import { filterFeedRecipes } from "../src/lib/feedFilter.ts";
import { isValidRecipe } from "../supabase/functions/_shared/recipeValidate.ts";
import {
  allowedSurpriseProteins,
  buildSurpriseBrief,
  parseSurpriseConstraints,
} from "../supabase/functions/_shared/surprise.ts";
import { recordRecipeTaste, recordVoteTaste } from "../src/lib/tasteMemory.ts";
import { isPreviewRecipe } from "../src/lib/surprise.ts";
import {
  addQuantities,
  formatQuantityNumber,
  scaleQuantity,
} from "../src/lib/quantity.ts";
import {
  fingerprintRecipe,
  signPreviewToken,
  verifyPreviewToken,
} from "../supabase/functions/_shared/previewToken.ts";
import {
  isNotificationsWebhook,
  pushCopy,
} from "../supabase/functions/_shared/pushCopy.ts";

// --- aisle ---
assert.equal(groceryAisle("Chicken thighs"), "Meat & Seafood");
assert.equal(groceryAisle("fresh basil"), "Produce");
assert.equal(groceryAisle("parmesan cheese"), "Dairy & Eggs");
assert.deepEqual(sortAisles(["Other", "Produce", "Pantry"]), [
  "Produce",
  "Pantry",
  "Other",
]);

// --- grocery merge ---
assert.equal(normalizeGroceryKey("  Extra-Virgin Olive Oil! "), "extra virgin olive oil");
assert.equal(mergeQuantities("1 cup", "1 cup"), "1 cup");
assert.equal(mergeQuantities("1 cup", "2 tbsp"), "1 cup + 2 tbsp");

// --- allergy ---
const hits = recipeMayContainAllergens(
  {
    title: "Peanut noodles",
    ingredients: [{ item: "peanut butter", quantity: "2 tbsp" }],
    steps: [{ instruction: "Stir well" }],
  },
  ["Peanuts", "Dairy"],
);
assert.ok(hits.includes("Peanuts"));

// --- feed filter ---
const recipes = [
  {
    id: "1",
    author_id: "a",
    title: "Quick Salad",
    description: "fresh",
    cuisine: "American",
    prep_time_minutes: 5,
    cook_time_minutes: 0,
    calories: 200,
    protein_g: 10,
    tags: ["Vegetarian"],
    ingredients: [],
    steps: [],
  },
  {
    id: "2",
    author_id: "b",
    title: "Slow Roast",
    description: "long",
    cuisine: "French",
    prep_time_minutes: 30,
    cook_time_minutes: 90,
    calories: 800,
    protein_g: 40,
    tags: ["High-protein"],
    ingredients: [],
    steps: [],
  },
];
const under20 = filterFeedRecipes(recipes, "", { kind: "time", maxMinutes: 20 }, [], new Set());
assert.equal(under20.length, 1);
assert.equal(under20[0].id, "1");

const lowCal = filterFeedRecipes(recipes, "", { kind: "cal", maxCalories: 500 }, [], new Set());
assert.equal(lowCal.length, 1);

// --- keepable recipe validation ---
assert.equal(
  isValidRecipe({
    title: "X",
    ingredients: [{ item: "a", quantity: "1" }, { item: "b", quantity: "1" }],
    steps: [{ instruction: "mix" }, { instruction: "serve" }],
  }),
  false,
  "old ≥2/≥2 floor is no longer keepable",
);
assert.equal(
  isValidRecipe({
    title: "Lemon Garlic Chicken",
    ingredients: [
      { item: "chicken thighs", quantity: "600 g" },
      { item: "lemon", quantity: "1" },
      { item: "garlic", quantity: "4 cloves" },
      { item: "olive oil", quantity: "2 tbsp" },
    ],
    steps: [
      { instruction: "Pat the chicken dry and season both sides with salt." },
      { instruction: "Sear skin-side down in a hot skillet until deep gold." },
      { instruction: "Add lemon and garlic, then roast until 165°F at the thickest point." },
    ],
  }),
  true,
);

// --- surprise brief is server-built and respects locks / diets ---
const veganBrief = buildSurpriseBrief({
  prefs: { diets: ["Vegan"], allergies: ["Peanuts"], learned: { cuisines: { Thai: 4 } } },
  constraints: parseSurpriseConstraints({
    cuisine: "Thai",
    max_minutes: 20,
    meal_slot: "dinner",
    pantry_mode: "fridge",
    ingredients: ["tofu", "spinach"],
  }),
  excludeTitles: ["Pad Thai"],
  random: () => 0,
});
assert.equal(veganBrief.cuisine, "Thai");
assert.equal(veganBrief.max_minutes, 20);
assert.equal(veganBrief.meal_slot, "dinner");
assert.ok(["tofu", "beans", "none"].includes(veganBrief.protein));
assert.match(veganBrief.prompt, /Thai/);
assert.match(veganBrief.prompt, /20 minutes/);
assert.match(veganBrief.prompt, /Pad Thai/);
assert.doesNotMatch(veganBrief.prompt, /chicken/i);

const junk = parseSurpriseConstraints({
  cuisine: "DROP TABLE recipes",
  max_minutes: 999,
  meal_slot: "brunch-party",
  pantry_mode: "wizard",
  method: "wizard",
  ingredients: ["  ", "x".repeat(80), 12],
});
assert.equal(junk.cuisine, null);
assert.equal(junk.max_minutes, null);
assert.equal(junk.meal_slot, null);
assert.equal(junk.pantry_mode, null);
assert.equal(junk.method, null);
assert.equal(junk.ingredients.length, 1);

const crock = buildSurpriseBrief({
  constraints: parseSurpriseConstraints({
    method: "slow_cooker",
    max_minutes: 15,
    pantry_mode: "leftover",
  }),
  random: () => 0,
});
assert.equal(crock.method, "slow_cooker");
assert.match(crock.prompt, /crock-pot \/ slow-cooker/);
assert.match(crock.prompt, /15 minutes/);

const veganProteins = allowedSurpriseProteins({
  diets: ["Vegan"],
  allergies: ["Soy"],
});
assert.ok(!veganProteins.includes("chicken"));
assert.ok(!veganProteins.includes("tofu"));
assert.ok(veganProteins.includes("beans"));

// --- taste memory + preview id ---
const preview = {
  id: "preview",
  cuisine: "Thai",
  base_protein: "tofu",
};
assert.equal(isPreviewRecipe(preview), true);
const liked = recordRecipeTaste(preview, {});
assert.ok((liked.learned?.cuisines?.Thai ?? 0) > 0);
const down = recordVoteTaste(preview, -1, liked);
assert.ok((down.learned?.cuisines?.Thai ?? 0) < (liked.learned?.cuisines?.Thai ?? 0));

// --- serving scaler (mirrors ios Quantity.swift) ---
assert.equal(scaleQuantity("to taste", 2), "to taste");
assert.equal(scaleQuantity("a handful", 3), "a handful");
assert.equal(scaleQuantity("2 × 150 g (5 oz)", 2), "4 × 150 g (5 oz)");
assert.equal(scaleQuantity("1½", 1.5), "2 ¼");
assert.equal(scaleQuantity("1 ½", 1.5), "2 ¼");
assert.equal(scaleQuantity("1 ½ cups", 1.5), "2 ¼ cups");
assert.equal(scaleQuantity("½ tsp salt plus 2 tbsp oil", 2), "1 tsp salt plus 2 tbsp oil");
assert.equal(formatQuantityNumber(2.25), "2 ¼");
assert.equal(addQuantities("1 cup", "½ cup"), "1 ½ cup");
assert.equal(addQuantities("1 cup", "2 tbsp"), "1 cup + 2 tbsp");
assert.equal(addQuantities("1 cup", "1 cup"), "1 cup");

// --- preview token: crafted JSON cannot keep without a prior generate ---
const previewRecipe = {
  title: "Lemon Garlic Chicken",
  description: "Bright skillet chicken",
  ingredients: [
    { item: "chicken thighs", quantity: "600 g" },
    { item: "lemon", quantity: "1" },
    { item: "garlic", quantity: "4 cloves" },
    { item: "olive oil", quantity: "2 tbsp" },
  ],
  steps: [
    { instruction: "Pat the chicken dry and season both sides with salt." },
    { instruction: "Sear skin-side down in a hot skillet until deep gold." },
    { instruction: "Add lemon and garlic, then roast until 165°F at the thickest point." },
  ],
  source_prompt: "surprise",
};
const tokenSecret = "preview-test-secret";
const previewToken = await signPreviewToken("user-1", previewRecipe, tokenSecret);
assert.equal(await verifyPreviewToken(previewToken, "user-1", previewRecipe, tokenSecret), true);
assert.equal(
  await verifyPreviewToken(previewToken, "user-1", { ...previewRecipe, title: "Crafted" }, tokenSecret),
  false,
);
assert.equal(await verifyPreviewToken(previewToken, "user-2", previewRecipe, tokenSecret), false);
assert.ok(fingerprintRecipe(previewRecipe).includes("lemon garlic chicken"));

// --- push-dispatch webhook copy + payload detect ---
assert.equal(
  pushCopy({ type: "vote", actorName: "sam", recipeTitle: "Chili" }).body,
  "sam liked Chili",
);
assert.equal(
  pushCopy({ type: "comment", actorName: null, recipeTitle: null }).title,
  "New comment",
);
assert.equal(isNotificationsWebhook({
  type: "INSERT",
  table: "notifications",
  record: { user_id: "u1", actor_id: "u2", recipe_id: "r1", type: "cook" },
}), true);
assert.equal(isNotificationsWebhook({
  deviceToken: "abc",
  title: "Hi",
  body: "There",
}), false);

console.log("smoke-tests: all passed");
