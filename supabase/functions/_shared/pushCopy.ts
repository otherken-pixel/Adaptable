/**
 * APNs title/body for `notifications` rows (vote / comment / cook).
 */

export type NotificationKind = "vote" | "comment" | "cook" | string;

export function pushCopy(opts: {
  type?: NotificationKind | null;
  actorName?: string | null;
  recipeTitle?: string | null;
}): { title: string; body: string } {
  const actor = (opts.actorName ?? "").trim() || "Someone";
  const recipe = (opts.recipeTitle ?? "").trim() || "your recipe";
  switch (opts.type) {
    case "vote":
      return { title: "New like", body: `${actor} liked ${recipe}` };
    case "comment":
      return { title: "New comment", body: `${actor} commented on ${recipe}` };
    case "cook":
      return { title: "Cooked it", body: `${actor} cooked ${recipe}` };
    default:
      return { title: "Adaptable", body: `${actor} interacted with ${recipe}` };
  }
}

export function isNotificationsWebhook(body: unknown): body is {
  type?: string;
  table?: string;
  record?: {
    user_id?: string;
    actor_id?: string | null;
    recipe_id?: string | null;
    type?: string;
  };
} {
  if (!body || typeof body !== "object") return false;
  const row = body as { table?: unknown; record?: unknown };
  if (row.table !== "notifications") return false;
  if (!row.record || typeof row.record !== "object") return false;
  const rec = row.record as { user_id?: unknown };
  return typeof rec.user_id === "string" && rec.user_id.length > 0;
}
