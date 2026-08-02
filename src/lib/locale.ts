/**
 * Locale-aware formatting helpers. EN-first for v1, but all dates/numbers
 * go through the user's locale so the app is ready for future strings.
 */

export function userLocale(): string {
  if (typeof navigator !== "undefined" && navigator.language) {
    return navigator.language;
  }
  return "en-US";
}

export function formatInteger(n: number, locale = userLocale()): string {
  return new Intl.NumberFormat(locale).format(n);
}

export function formatList(items: string[], locale = userLocale()): string {
  try {
    return new Intl.ListFormat(locale, { style: "short", type: "conjunction" }).format(
      items,
    );
  } catch {
    return items.join(", ");
  }
}

/** Short relative time already lives in format.ts — re-export locale for callers. */
export { userLocale as appLocale };
