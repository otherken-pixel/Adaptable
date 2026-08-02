/**
 * Map grocery item names → rough store aisle for shopping UX.
 * Keep lists short and lowercase; first match wins.
 */

const AISLE_RULES: Array<{ aisle: string; keywords: string[] }> = [
  { aisle: "Produce", keywords: ["lettuce", "tomato", "onion", "garlic", "potato", "spinach", "herb", "cilantro", "basil", "lemon", "lime", "avocado", "pepper", "carrot", "celery", "mushroom", "apple", "berry", "fruit", "vegetable", "greens", "ginger", "cucumber", "zucchini", "broccoli", "kale", "parsley", "scallion", "shallot"] },
  { aisle: "Meat & Seafood", keywords: ["chicken", "beef", "pork", "turkey", "lamb", "sausage", "bacon", "salmon", "tuna", "shrimp", "fish", "steak", "ground"] },
  { aisle: "Dairy & Eggs", keywords: ["milk", "butter", "cheese", "yogurt", "yoghurt", "cream", "egg", "parmesan", "mozzarella", "feta", "cheddar"] },
  { aisle: "Bakery", keywords: ["bread", "bun", "tortilla", "pita", "bagel", "roll", "baguette"] },
  { aisle: "Pantry", keywords: ["rice", "pasta", "noodle", "flour", "sugar", "oil", "vinegar", "soy sauce", "broth", "stock", "bean", "lentil", "chickpea", "canned", "tomato paste", "spice", "salt", "pepper", "honey", "maple", "sauce", "mustard", "mayo", "ketchup", "stock cube"] },
  { aisle: "Frozen", keywords: ["frozen", "ice cream", "peas"] },
  { aisle: "Drinks", keywords: ["wine", "beer", "juice", "soda", "water", "coffee", "tea"] },
];

export function groceryAisle(itemName: string): string {
  const hay = itemName.toLowerCase();
  for (const rule of AISLE_RULES) {
    if (rule.keywords.some((k) => hay.includes(k))) return rule.aisle;
  }
  return "Other";
}

/** Stable sort order for aisle sections. */
export const AISLE_ORDER = [
  "Produce",
  "Meat & Seafood",
  "Dairy & Eggs",
  "Bakery",
  "Pantry",
  "Frozen",
  "Drinks",
  "Other",
];

export function sortAisles(aisles: string[]): string[] {
  return [...aisles].sort((a, b) => {
    const ia = AISLE_ORDER.indexOf(a);
    const ib = AISLE_ORDER.indexOf(b);
    return (ia === -1 ? 99 : ia) - (ib === -1 ? 99 : ib);
  });
}
