import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Bell, Search, Sparkles, X } from "lucide-react";
import { fetchFeed } from "@/lib/api";
import type { FeedSort, Recipe } from "@/lib/types";
import RecipeCard from "@/components/RecipeCard";
import { FeedSkeleton } from "@/components/Skeletons";
import EmptyState from "@/components/EmptyState";
import { useAuth } from "@/context/AuthContext";
import { useNotifications } from "@/context/NotificationsContext";

type Chip =
  | { kind: "all"; label: string }
  | { kind: "time"; label: string; maxMinutes: number }
  | { kind: "cal"; label: string; maxCalories: number }
  | { kind: "tag"; label: string };

export default function FeedPage() {
  const [sort, setSort] = useState<FeedSort>("hot");
  const [recipes, setRecipes] = useState<Recipe[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [chipIdx, setChipIdx] = useState(0);
  const { isDemo } = useAuth();
  const { unreadCount } = useNotifications();

  useEffect(() => {
    let cancelled = false;
    setRecipes(null);
    setError(null);
    fetchFeed(sort)
      .then((r) => !cancelled && setRecipes(r))
      .catch(() => !cancelled && setError("Couldn't load the feed. Pull to retry."));
    return () => {
      cancelled = true;
    };
  }, [sort]);

  // Filter chips: fixed time filters + the most common tags in the feed.
  const chips = useMemo<Chip[]>(() => {
    const counts = new Map<string, number>();
    for (const r of recipes ?? []) {
      for (const t of r.tags) counts.set(t, (counts.get(t) ?? 0) + 1);
    }
    const topTags = [...counts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 6)
      .map(([t]) => t);
    return [
      { kind: "all", label: "All" },
      { kind: "time", label: "Under 20 min", maxMinutes: 20 },
      { kind: "cal", label: "Low-cal", maxCalories: 500 },
      { kind: "time", label: "Under 45 min", maxMinutes: 45 },
      ...topTags.map((t): Chip => ({ kind: "tag", label: t })),
    ];
  }, [recipes]);

  const filtered = useMemo(() => {
    if (!recipes) return null;
    const q = search.trim().toLowerCase();
    const chip = chips[Math.min(chipIdx, chips.length - 1)];
    return recipes.filter((r) => {
      if (q) {
        const haystack = [r.title, r.description, r.cuisine, ...r.tags]
          .join(" ")
          .toLowerCase();
        if (!haystack.includes(q)) return false;
      }
      if (chip.kind === "time") {
        return r.prep_time_minutes + r.cook_time_minutes <= chip.maxMinutes;
      }
      if (chip.kind === "cal") {
        // Recipes without calorie data can't claim to be low-cal.
        return r.calories !== null && r.calories <= chip.maxCalories;
      }
      if (chip.kind === "tag") {
        return r.tags.some((t) => t.toLowerCase() === chip.label.toLowerCase());
      }
      return true;
    });
  }, [recipes, search, chipIdx, chips]);

  return (
    <div className="mx-auto max-w-lg px-4 pt-safe pb-nav">
      {/* Header */}
      <header className="flex items-end justify-between pt-6 pb-4">
        <div>
          <p className="text-xs font-bold tracking-[0.18em] text-accent uppercase">
            Adaptable
          </p>
          <h1 className="mt-1 text-[32px] leading-none font-extrabold tracking-tight">
            Discover
          </h1>
        </div>
        <div className="flex flex-col items-end gap-2.5">
          <Link
            to="/activity"
            aria-label="Activity"
            className="pressable relative flex h-10 w-10 items-center justify-center rounded-full border border-line bg-raised shadow-sm"
          >
            <Bell size={18} strokeWidth={2.2} className="text-muted" />
            {unreadCount > 0 && (
              <span className="animate-pop absolute -top-1 -right-1 flex h-5 min-w-5 items-center justify-center rounded-full bg-accent px-1 text-[10px] font-extrabold text-white">
                {unreadCount > 99 ? "99" : unreadCount}
              </span>
            )}
          </Link>
          <SortToggle sort={sort} onChange={setSort} />
        </div>
      </header>

      {/* Search + filter chips */}
      <div className="mb-4 space-y-3">
        <div className="flex items-center gap-2 rounded-2xl border border-line bg-raised px-3.5">
          <Search size={17} strokeWidth={2.2} className="shrink-0 text-faint" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search recipes, tags, cuisines…"
            className="h-11 min-w-0 flex-1 bg-transparent text-[15px] outline-none placeholder:text-faint"
          />
          {search && (
            <button
              aria-label="Clear search"
              onClick={() => setSearch("")}
              className="pressable flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-sunken text-muted"
            >
              <X size={13} strokeWidth={2.6} />
            </button>
          )}
        </div>
        <div className="scrollbar-none -mx-4 flex gap-2 overflow-x-auto px-4">
          {chips.map((c, i) => (
            <button
              key={c.label}
              onClick={() => setChipIdx(i)}
              className={`pressable shrink-0 rounded-full px-4 py-1.5 text-[13px] font-bold whitespace-nowrap transition-colors ${
                i === chipIdx
                  ? "bg-content text-surface"
                  : "border border-line bg-raised text-muted"
              }`}
            >
              {c.label}
            </button>
          ))}
        </div>
      </div>

      {isDemo && (
        <div className="animate-fade-up mb-4 flex items-center gap-2.5 rounded-2xl bg-accent-soft px-4 py-3 text-[13px] leading-snug font-medium text-accent">
          <Sparkles size={16} className="shrink-0" />
          Demo Mode — add Supabase keys in .env to go live. Everything here still
          works locally.
        </div>
      )}

      {error && (
        <EmptyState
          emoji="📡"
          title="Connection hiccup"
          body={error}
          action={
            <button
              onClick={() => setSort((s) => s)}
              className="pressable rounded-full bg-content px-5 py-2 text-sm font-bold text-surface"
            >
              Retry
            </button>
          }
        />
      )}

      {!error && filtered === null && <FeedSkeleton />}

      {!error && filtered !== null && filtered.length === 0 && (
        <EmptyState
          emoji={search || chipIdx > 0 ? "🔍" : "🍳"}
          title={search || chipIdx > 0 ? "No matches" : "Nothing cooking yet"}
          body={
            search || chipIdx > 0
              ? "Try a different search or filter — or generate exactly what you're craving."
              : "Be the first — describe what you're craving and let the AI take it from there."
          }
          action={
            <Link
              to="/create"
              className="pressable rounded-full bg-content px-5 py-2 text-sm font-bold text-surface"
            >
              Generate a recipe
            </Link>
          }
        />
      )}

      {!error && filtered !== null && filtered.length > 0 && (
        <div className="space-y-4">
          {filtered.map((r, i) => (
            <RecipeCard key={r.id} recipe={r} index={i} />
          ))}
        </div>
      )}
    </div>
  );
}

function SortToggle({
  sort,
  onChange,
}: {
  sort: FeedSort;
  onChange: (s: FeedSort) => void;
}) {
  const options: Array<{ id: FeedSort; label: string }> = [
    { id: "hot", label: "🔥 Hot" },
    { id: "top", label: "Top" },
    { id: "new", label: "New" },
  ];
  return (
    <div className="flex rounded-full bg-sunken p-1">
      {options.map(({ id, label }) => (
        <button
          key={id}
          onClick={() => onChange(id)}
          className={`pressable rounded-full px-3 py-1.5 text-[13px] font-bold whitespace-nowrap transition-colors ${
            sort === id ? "bg-raised text-content shadow-sm" : "text-muted"
          }`}
        >
          {label}
        </button>
      ))}
    </div>
  );
}
