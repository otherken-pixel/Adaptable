/**
 * Shared allergy scanning + daily rate limits for generate/import edge functions.
 * Allergen table + token matcher live in allergenLexicon.ts (iOS lockstep).
 */

export {
  findAllergyViolations,
  findIngredientAllergyViolations,
} from "./allergenLexicon.ts";

export function extractAllergies(prefs: unknown): string[] {
  if (!prefs || typeof prefs !== "object") return [];
  const allergies = (prefs as { allergies?: unknown }).allergies;
  if (!Array.isArray(allergies)) return [];
  return allergies.map(String).map((s) => s.trim()).filter(Boolean);
}

/** Action name for surprise / preview generations that do not insert yet. */
export const GENERATION_USAGE_ACTION = "generation";

/** Soft daily cap: recipes authored today (UTC) plus preview generations. */
/** Optional ops hook when a content report is filed (set REPORT_WEBHOOK_URL). */
export async function notifyReport(payload: {
  targetType: string;
  targetId: string;
  reason: string;
  reporterId: string;
}): Promise<void> {
  const url = Deno.env.get("REPORT_WEBHOOK_URL");
  if (!url) return;
  try {
    await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        text: `Adaptable report: ${payload.targetType} ${payload.targetId} — ${payload.reason} (by ${payload.reporterId})`,
        ...payload,
      }),
    });
  } catch (e) {
    console.error("report webhook failed", e);
  }
}

export async function assertDailyRecipeLimit(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
  limit: number,
  actionLabel: string,
): Promise<{ ok: true } | { ok: false; status: number; error: string }> {
  const start = new Date();
  start.setUTCHours(0, 0, 0, 0);

  const { count, error } = await supabase
    .from("recipes")
    .select("id", { count: "exact", head: true })
    .eq("author_id", userId)
    .gte("created_at", start.toISOString());

  if (error) {
    console.error("rate limit count failed", error);
    // Fail open on counter errors so a DB blip doesn't block cooking.
    return { ok: true };
  }

  let extra = 0;
  const { count: eventCount, error: eventError } = await supabase
    .from("ai_usage_events")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("action", GENERATION_USAGE_ACTION)
    .gte("created_at", start.toISOString());
  if (eventError) {
    console.error("rate limit event count failed", eventError);
  } else {
    extra = eventCount ?? 0;
  }

  if ((count ?? 0) + extra >= limit) {
    return {
      ok: false,
      status: 429,
      error: `Daily ${actionLabel} limit reached (${limit}/day). Try again tomorrow — this keeps the AI kitchen fair for everyone.`,
    };
  }
  return { ok: true };
}

/** Count a preview generation against the shared daily cap (no recipe row yet). */
export async function recordGenerationEvent(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
): Promise<void> {
  const { error } = await supabase.from("ai_usage_events").insert({
    user_id: userId,
    action: GENERATION_USAGE_ACTION,
  });
  if (error) {
    console.error("generation usage insert failed", error);
  }
}

/** Soft daily cap for actions that do not insert a recipe (e.g. fridge reads). */
export async function assertDailyActionLimit(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
  action: string,
  limit: number,
  actionLabel: string,
): Promise<{ ok: true } | { ok: false; status: number; error: string }> {
  const start = new Date();
  start.setUTCHours(0, 0, 0, 0);

  const { count, error } = await supabase
    .from("ai_usage_events")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("action", action)
    .gte("created_at", start.toISOString());

  if (error) {
    console.error("action rate limit count failed", error);
    return { ok: true };
  }

  if ((count ?? 0) >= limit) {
    return {
      ok: false,
      status: 429,
      error: `Daily ${actionLabel} limit reached (${limit}/day). Try again tomorrow — this keeps the AI kitchen fair for everyone.`,
    };
  }

  const { error: insertError } = await supabase.from("ai_usage_events").insert({
    user_id: userId,
    action,
  });
  if (insertError) {
    console.error("action rate limit insert failed", insertError);
  }
  return { ok: true };
}
