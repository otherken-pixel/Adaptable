/**
 * Client-side allergy awareness helpers (UI badges + disclaimers).
 * Server-side hard checks live in supabase/functions/_shared/safety.ts.
 */

const ALIASES: Record<string, string[]> = {
  peanut: ["peanut", "peanuts", "groundnut"],
  peanuts: ["peanut", "peanuts", "groundnut"],
  dairy: ["milk", "butter", "cheese", "cream", "yogurt", "yoghurt", "whey"],
  milk: ["milk", "butter", "cheese", "cream", "yogurt", "whey"],
  egg: ["egg", "eggs", "mayonnaise"],
  eggs: ["egg", "eggs", "mayonnaise"],
  gluten: ["wheat", "barley", "rye", "malt", "flour", "breadcrumbs", "pasta"],
  wheat: ["wheat", "flour", "breadcrumbs"],
  shellfish: ["shrimp", "prawn", "crab", "lobster", "scallop", "clam", "mussel"],
  fish: ["fish", "salmon", "tuna", "cod", "anchovy", "sardine"],
  soy: ["soy", "soya", "tofu", "tempeh", "edamame", "miso"],
  sesame: ["sesame", "tahini"],
};

function termsFor(label: string): string[] {
  const key = label.toLowerCase().trim();
  return ALIASES[key] ?? ALIASES[key.replace(/s$/, "")] ?? [key];
}

export function recipeMayContainAllergens(
  recipe: {
    title?: string;
    description?: string;
    ingredients?: Array<{ item?: string; note?: string }>;
    steps?: Array<{ instruction?: string }>;
  },
  allergies: string[] | undefined,
): string[] {
  if (!allergies?.length) return [];
  const hay = [
    recipe.title ?? "",
    recipe.description ?? "",
    ...(recipe.ingredients ?? []).map((i) => `${i.item ?? ""} ${i.note ?? ""}`),
    ...(recipe.steps ?? []).map((s) => s.instruction ?? ""),
  ]
    .join(" ")
    .toLowerCase();

  const hits: string[] = [];
  for (const a of allergies) {
    if (termsFor(a).some((t) => t.length >= 3 && hay.includes(t))) {
      hits.push(a);
    }
  }
  return [...new Set(hits)];
}
