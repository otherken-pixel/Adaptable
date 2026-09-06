/**
 * Shared allergen lexicon + token-aware matcher.
 *
 * Used by generate/import/adapt/bundle (via safety.ts) and by
 * `src/lib/allergy.ts`. Keep `ios/.../Utilities/AllergenLexicon.swift`
 * in lockstep — same keys, terms, exceptions, and token rules.
 *
 * Matching is word-boundary / token-window, never naive substring ≥3.
 * That stops fish⊂shellfish, cream⊂creamy, and lets exceptions skip
 * coconut cream / cream of tartar / rice flour / almond flour.
 */

export type AllergenRule = {
  terms: string[];
  exceptions: string[];
};

/** Taste Profile chips, including Mustard (aliases live in the table). */
export const TASTE_PROFILE_ALLERGY_CHIPS = [
  "Peanuts",
  "Tree nuts",
  "Shellfish",
  "Fish",
  "Eggs",
  "Dairy",
  "Gluten",
  "Soy",
  "Sesame",
  "Mustard",
] as const;

const DAIRY_EXCEPTIONS = [
  "coconut cream",
  "cream of tartar",
  "coconut milk",
  "almond milk",
  "oat milk",
  "soy milk",
  "soya milk",
  "rice milk",
  "cashew milk",
  "hemp milk",
  "pea milk",
  "flax milk",
  "macadamia milk",
  "peanut butter",
  "almond butter",
  "cashew butter",
  "sunflower butter",
  "cookie butter",
  "cocoa butter",
  "shea butter",
  "nut butter",
];

const FLOUR_EXCEPTIONS = [
  "rice flour",
  "almond flour",
  "coconut flour",
  "chickpea flour",
  "garbanzo flour",
  "tapioca flour",
  "potato flour",
  "corn flour",
  "oat flour",
  "buckwheat flour",
  "sorghum flour",
  "millet flour",
  "teff flour",
];

/**
 * Canonical key → terms that indicate presence + exception phrases
 * that contain a term but are not that allergen.
 */
export const ALLERGEN_RULES: Record<string, AllergenRule> = {
  peanut: {
    terms: ["peanut", "peanuts", "groundnut", "groundnuts", "ground nut", "arachis"],
    exceptions: [],
  },
  "tree nut": {
    terms: [
      "almond", "almonds", "cashew", "cashews", "walnut", "walnuts",
      "pecan", "pecans", "pistachio", "pistachios", "hazelnut", "hazelnuts",
      "macadamia", "macadamias", "brazil nut", "brazil nuts", "pine nut",
      "pine nuts", "tree nut", "tree nuts", "nutella", "marzipan",
    ],
    exceptions: [],
  },
  dairy: {
    terms: [
      "milk", "butter", "cheese", "cream", "yogurt", "yoghurt", "whey",
      "casein", "lactose", "ghee", "paneer", "mozzarella", "cheddar",
      "parmesan", "parmigiano", "feta", "ricotta", "brie", "gouda",
      "gruyere", "halloumi", "mascarpone", "cottage cheese", "sour cream",
      "creme fraiche", "half and half", "buttermilk", "ice cream",
    ],
    exceptions: DAIRY_EXCEPTIONS,
  },
  egg: {
    terms: ["egg", "eggs", "mayonnaise", "aioli", "meringue"],
    exceptions: [],
  },
  gluten: {
    terms: [
      "wheat", "barley", "rye", "malt", "seitan", "flour", "breadcrumbs",
      "bread crumbs", "soy sauce", "pasta", "couscous", "farro", "spelt",
    ],
    exceptions: FLOUR_EXCEPTIONS,
  },
  wheat: {
    terms: ["wheat", "flour", "breadcrumbs", "bread crumbs", "seitan", "bulgur"],
    exceptions: FLOUR_EXCEPTIONS,
  },
  shellfish: {
    terms: [
      "shrimp", "prawn", "prawns", "crab", "lobster", "crawfish", "crayfish",
      "scallop", "scallops", "clam", "clams", "mussel", "mussels", "oyster",
      "oysters", "shellfish", "calamari", "squid", "oyster sauce",
    ],
    exceptions: [],
  },
  fish: {
    terms: [
      "fish", "salmon", "tuna", "cod", "anchovy", "anchovies", "sardine",
      "sardines", "trout", "bass", "halibut", "tilapia", "fish sauce",
      "worcestershire", "nam pla", "nuoc mam", "dashi", "bonito",
      "katsuobushi",
    ],
    exceptions: [],
  },
  soy: {
    terms: [
      "soy", "soya", "tofu", "tempeh", "edamame", "miso", "soy sauce", "tamari",
    ],
    exceptions: [],
  },
  sesame: {
    terms: ["sesame", "tahini", "benne", "hummus"],
    exceptions: [],
  },
  mustard: {
    terms: [
      "mustard", "dijon", "mustard seed", "mustard seeds", "mustard powder",
      "english mustard", "yellow mustard", "brown mustard",
    ],
    exceptions: [],
  },
};

const LABEL_TO_CANONICAL: Record<string, string> = {
  peanut: "peanut",
  peanuts: "peanut",
  "tree nut": "tree nut",
  "tree nuts": "tree nut",
  dairy: "dairy",
  milk: "dairy",
  egg: "egg",
  eggs: "egg",
  gluten: "gluten",
  wheat: "wheat",
  shellfish: "shellfish",
  fish: "fish",
  soy: "soy",
  sesame: "sesame",
  mustard: "mustard",
};

export function canonicalAllergyKey(label: string): string {
  const key = label.toLowerCase().trim().replace(/[-_]+/g, " ");
  if (LABEL_TO_CANONICAL[key]) return LABEL_TO_CANONICAL[key];
  const bare = key.replace(/s$/, "");
  if (LABEL_TO_CANONICAL[bare]) return LABEL_TO_CANONICAL[bare];
  return key;
}

export function termsForAllergy(label: string): string[] {
  return rulesFor(label).flatMap((rule) => rule.terms);
}

function rulesFor(label: string): AllergenRule[] {
  const key = canonicalAllergyKey(label);
  if (key === "nut" || key === "nuts") {
    return [ALLERGEN_RULES.peanut, ALLERGEN_RULES["tree nut"]];
  }
  if (ALLERGEN_RULES[key]) return [ALLERGEN_RULES[key]];
  const custom = label.toLowerCase().trim();
  return custom ? [{ terms: [custom], exceptions: [] }] : [];
}

/** Lowercase, strip punctuation, collapse to tokens. */
export function tokenizeAllergenHay(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/['’]/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
}

function windowEquals(hay: string[], start: number, term: string[]): boolean {
  if (start + term.length > hay.length) return false;
  return term.every((t, i) => hay[start + i] === t);
}

function isExcepted(
  hay: string[],
  start: number,
  len: number,
  exceptions: string[],
): boolean {
  for (const ex of exceptions) {
    const exTokens = tokenizeAllergenHay(ex);
    if (!exTokens.length) continue;
    for (let i = 0; i <= hay.length - exTokens.length; i++) {
      const overlaps = i < start + len && i + exTokens.length > start;
      if (overlaps && windowEquals(hay, i, exTokens)) return true;
    }
  }
  return false;
}

export function hayContainsTerm(
  hay: string[],
  term: string,
  exceptions: string[],
): boolean {
  const termTokens = tokenizeAllergenHay(term);
  if (!termTokens.length) return false;
  for (let i = 0; i <= hay.length - termTokens.length; i++) {
    if (!windowEquals(hay, i, termTokens)) continue;
    if (!isExcepted(hay, i, termTokens.length, exceptions)) return true;
  }
  return false;
}

export type AllergenScanRecipe = {
  title?: string;
  description?: string;
  ingredients?: Array<{ item?: string; note?: string }>;
  steps?: Array<{ instruction?: string; tip?: string }>;
};

function hayTokensFor(
  recipe: AllergenScanRecipe,
  ingredientsOnly: boolean,
): string[] {
  const chunks: string[] = ingredientsOnly
    ? []
    : [recipe.title ?? "", recipe.description ?? ""];
  for (const ing of recipe.ingredients ?? []) {
    chunks.push(`${ing.item ?? ""} ${ing.note ?? ""}`);
  }
  if (!ingredientsOnly) {
    for (const step of recipe.steps ?? []) {
      chunks.push(`${step.instruction ?? ""} ${step.tip ?? ""}`);
    }
  }
  return tokenizeAllergenHay(chunks.join(" "));
}

function hitsForAllergies(
  hay: string[],
  allergies: string[],
): string[] {
  if (!allergies.length || !hay.length) return [];
  const hits: string[] = [];
  for (const allergy of allergies) {
    const matched = rulesFor(allergy).some((rule) =>
      rule.terms.some((term) => hayContainsTerm(hay, term, rule.exceptions)),
    );
    if (matched) hits.push(allergy);
  }
  return [...new Set(hits)];
}

/** Full-recipe scan used by generate/import/adapt/bundle (422). */
export function findAllergyViolations(
  recipe: AllergenScanRecipe,
  allergies: string[],
): string[] {
  return hitsForAllergies(hayTokensFor(recipe, false), allergies);
}

/** Ingredient-only scan used by Cook Mode hard-block. */
export function findIngredientAllergyViolations(
  recipe: AllergenScanRecipe,
  allergies: string[],
): string[] {
  return hitsForAllergies(hayTokensFor(recipe, true), allergies);
}
