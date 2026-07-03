/**
 * Parse and scale free-text ingredient quantities like "2 × 150 g (5 oz)",
 * "1 ½ cups", "½", "2.5 tbsp". Only the first numeric token is scaled;
 * text without numbers ("to taste", "a handful") passes through unchanged.
 */

const UNICODE_FRACTIONS: Record<string, number> = {
  "¼": 0.25,
  "½": 0.5,
  "¾": 0.75,
  "⅓": 1 / 3,
  "⅔": 2 / 3,
  "⅛": 0.125,
  "⅜": 0.375,
  "⅝": 0.625,
  "⅞": 0.875,
};

const NICE_FRACTIONS: Array<[number, string]> = [
  [0, ""],
  [0.125, "⅛"],
  [0.25, "¼"],
  [1 / 3, "⅓"],
  [0.375, "⅜"],
  [0.5, "½"],
  [0.625, "⅝"],
  [2 / 3, "⅔"],
  [0.75, "¾"],
  [0.875, "⅞"],
  [1, ""],
];

// Leading numeric token: "1 ½", "1 1/2", "2.5", "2,5", "3/4", "½", "12"
const NUMBER_RE =
  /(\d+(?:[.,]\d+)?\s+\d+\/\d+|\d+\s*[¼½¾⅓⅔⅛⅜⅝⅞]|\d+\/\d+|\d+(?:[.,]\d+)?|[¼½¾⅓⅔⅛⅜⅝⅞])/;

function parseNumeric(raw: string): number | null {
  const s = raw.trim();
  if (s in UNICODE_FRACTIONS) return UNICODE_FRACTIONS[s];

  const mixedUnicode = s.match(/^(\d+)\s*([¼½¾⅓⅔⅛⅜⅝⅞])$/);
  if (mixedUnicode) {
    return parseInt(mixedUnicode[1], 10) + UNICODE_FRACTIONS[mixedUnicode[2]];
  }

  const mixedSlash = s.match(/^(\d+(?:[.,]\d+)?)\s+(\d+)\/(\d+)$/);
  if (mixedSlash) {
    const denom = parseInt(mixedSlash[3], 10);
    if (!denom) return null;
    return (
      parseFloat(mixedSlash[1].replace(",", ".")) +
      parseInt(mixedSlash[2], 10) / denom
    );
  }

  const slash = s.match(/^(\d+)\/(\d+)$/);
  if (slash) {
    const denom = parseInt(slash[2], 10);
    if (!denom) return null;
    return parseInt(slash[1], 10) / denom;
  }

  const plain = parseFloat(s.replace(",", "."));
  return Number.isFinite(plain) ? plain : null;
}

/** Render a number as a cook-friendly string ("1 ½", "¾", "2.3"). */
export function formatQuantityNumber(value: number): string {
  if (value <= 0) return "0";
  const whole = Math.floor(value + 1e-9);
  const frac = value - whole;

  let best: [number, string] = NICE_FRACTIONS[0];
  let bestDist = Infinity;
  for (const candidate of NICE_FRACTIONS) {
    const d = Math.abs(frac - candidate[0]);
    if (d < bestDist) {
      bestDist = d;
      best = candidate;
    }
  }

  if (bestDist > 0.04) {
    const rounded = Math.round(value * 10) / 10;
    return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1);
  }

  let w = whole;
  let f = best[1];
  if (best[0] === 1) {
    w += 1;
    f = "";
  }
  if (w === 0) return f || "0";
  return f ? `${w} ${f}` : String(w);
}

/** Scale the first number found in a quantity string by `factor`. */
export function scaleQuantity(quantity: string, factor: number): string {
  if (Math.abs(factor - 1) < 1e-9) return quantity;
  const match = quantity.match(NUMBER_RE);
  if (!match || match.index === undefined) return quantity;
  const value = parseNumeric(match[0]);
  if (value === null) return quantity;
  const scaled = formatQuantityNumber(value * factor);
  return (
    quantity.slice(0, match.index) +
    scaled +
    quantity.slice(match.index + match[0].length)
  );
}
