import { useEffect } from "react";
import { Link } from "react-router-dom";
import { ArrowBigUp, CheckCheck, CookingPot, MessageCircle } from "lucide-react";
import { useNotifications } from "@/context/NotificationsContext";
import { coverGradient } from "@/lib/gradients";
import { timeAgo } from "@/lib/format";
import EmptyState from "@/components/EmptyState";
import type { NotificationType } from "@/lib/types";

const TYPE_META: Record<
  NotificationType,
  { icon: typeof ArrowBigUp; verb: string; className: string }
> = {
  vote: { icon: ArrowBigUp, verb: "upvoted", className: "bg-up/15 text-up" },
  comment: {
    icon: MessageCircle,
    verb: "commented on",
    className: "bg-accent-soft text-accent",
  },
  cook: { icon: CookingPot, verb: "just cooked", className: "bg-down/10 text-down" },
};

export default function ActivityPage() {
  const { items, unreadCount, markAllRead } = useNotifications();

  // Opening the inbox clears the badge (small delay so unread dots are
  // visible for a beat before fading into "read" state on next visit).
  useEffect(() => {
    if (unreadCount === 0) return;
    const t = setTimeout(markAllRead, 1500);
    return () => clearTimeout(t);
  }, [unreadCount, markAllRead]);

  return (
    <div className="mx-auto max-w-lg px-4 pt-safe pb-nav">
      <header className="flex items-end justify-between pt-6 pb-4">
        <div>
          <p className="text-xs font-bold tracking-[0.18em] text-accent uppercase">
            {unreadCount > 0 ? `${unreadCount} new` : "All caught up"}
          </p>
          <h1 className="mt-1 text-[32px] leading-none font-extrabold tracking-tight">
            Activity
          </h1>
        </div>
        {unreadCount > 0 && (
          <button
            onClick={markAllRead}
            className="pressable flex items-center gap-1.5 rounded-full bg-sunken px-4 py-2 text-[13px] font-bold text-muted"
          >
            <CheckCheck size={14} strokeWidth={2.4} />
            Mark read
          </button>
        )}
      </header>

      {items.length === 0 && (
        <EmptyState
          emoji="🔔"
          title="No activity yet"
          body="Publish a recipe and you'll hear it here the moment someone upvotes, comments or cooks it."
          action={
            <Link
              to="/create"
              className="pressable rounded-full bg-content px-5 py-2 text-sm font-bold text-surface"
            >
              Create a recipe
            </Link>
          }
        />
      )}

      <div className="space-y-2.5">
        {items.map((n, i) => {
          const meta = TYPE_META[n.type];
          const Icon = meta.icon;
          return (
            <Link
              key={n.id}
              to={n.recipe_id ? `/recipe/${n.recipe_id}` : "/"}
              className="animate-fade-up flex items-center gap-3 rounded-2xl border border-line bg-raised p-3.5"
              style={{ animationDelay: `${Math.min(i, 8) * 45}ms` }}
            >
              <div className="relative shrink-0">
                <span
                  className="flex h-11 w-11 items-center justify-center rounded-full text-sm font-bold text-white"
                  style={{
                    background: coverGradient(n.actor?.username ?? n.actor_id ?? "?"),
                  }}
                >
                  {(n.actor?.username ?? "?").slice(0, 1).toUpperCase()}
                </span>
                <span
                  className={`absolute -right-1 -bottom-1 flex h-5 w-5 items-center justify-center rounded-full border-2 border-raised ${meta.className}`}
                >
                  <Icon size={11} strokeWidth={2.6} />
                </span>
              </div>
              <p className="min-w-0 flex-1 text-[14px] leading-snug">
                <span className="font-bold">{n.actor?.username ?? "Someone"}</span>{" "}
                <span className="text-muted">{meta.verb}</span>{" "}
                <span className="font-semibold">
                  {n.recipe ? `${n.recipe.emoji} ${n.recipe.title}` : "your recipe"}
                </span>
                <span className="mt-0.5 block text-xs text-faint">
                  {timeAgo(n.created_at)}
                </span>
              </p>
              {!n.read && (
                <span className="h-2.5 w-2.5 shrink-0 rounded-full bg-accent" />
              )}
            </Link>
          );
        })}
      </div>
    </div>
  );
}
