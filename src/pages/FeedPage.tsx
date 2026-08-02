import { useCallback, useEffect, useMemo, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { Bell, Search, Sparkles, X } from "lucide-react";
import { fetchFeed } from "@/lib/api";
import { filterFeedRecipes, type FeedChip } from "@/lib/feedFilter";
import type { FeedSort, Recipe } from "@/lib/types";
import RecipeCard from "@/components/RecipeCard";
import { FeedSkeleton } from "@/components/Skeletons";
import EmptyState from "@/components/EmptyState";
import { useAuth } from "@/context/AuthContext";
import { useNotifications } from "@/context/NotificationsContext";
import { useEngagement } from "@/context/EngagementContext";

const TASTE_NUDGE_KEY = "adaptable.tasteNudge.v1.dismissed";

type Chip =
  | { id: string; kind: "all"; label: string }
  | { id: string; kind: "foryou"; label: string }
  | { id: string; kind: "following"; label: string }
  | { id: string; kind: "time"; label: string; maxMinutes: number }
  | { id: string; kind: "cal"; label: string; maxCalories: number }
  | { id: string; kind: "protein"; label: string; minProtein: number }
  | { id: string; kind: "tag"; label: string };

function toFeedChip(chip: Chip): FeedChip {
  switch (chip.kind) {
    case "all":
      return { kind: "all" };
    case "foryou":
      return { kind: "foryou" };
    case "following":
      return { kind: "following" };
    case "time":
      return { kind: "time", maxMinutes: chip.maxMinutes };
    case "cal":
      return { kind: "cal", maxCalories: chip.maxCalories };
    case "protein":
      return { kind: "protein", minProtein: chip.minProtein };
    case "tag":
      return { kind: "tag", label: chip.label };
  }
}

const tagChipId = (label: string) => `tag:${label.toLowerCase()}`;

// Tags that would duplicate a built-in filter chip.
const BUILTIN_TAG_LABELS = new Set(["high-protein", "low-cal"]);

export default function FeedPage() {
  const [sort, setSort] = useState<FeedSort>("hot");
  const [recipes, setRecipes] = useState<Recipe[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [activeChipId, setActiveChipId] = useState("all");
  const [showDebugInfo, setShowDebugInfo] = useState(false);
  const [showTasteNudge, setShowTasteNudge] = useState(false);
  const { profile } = useAuth();
  const { unreadCount } = useNotifications();
  const { followedIds } = useEngagement();

  useEffect(() => {
    if (!profile) return;
    if (localStorage.getItem(TASTE_NUDGE_KEY)) return;
    const prefs = profile.preferences;
    const empty =
      !(prefs?.diets?.length) &&
      !(prefs?.allergies?.length) &&
      !(prefs?.dislikes?.length);
    if (!empty) {
      localStorage.setItem(TASTE_NUDGE_KEY, "1");
      return;
    }
    setShowTasteNudge(true);
  }, [profile]);

  // Deep link: /?tag=High-protein (recipe tag pills navigate here).
  const [params, setParams] = useSearchParams();
  const tagParam = params.get("tag");
  useEffect(() => {
    if (tagParam) setActiveChipId(tagChipId(tagParam));
  }, [tagParam]);

  const load = useCallback(() => {
    let cancelled = false;
    setRecipes(null);
    setError(null);
    fetchFeed(sort)
      .then((r) => !cancelled && setRecipes(r))
      .catch(
        (e) => !cancelled && setError(e?.message ?? "Couldn't load the feed."),
      );
    return () => {
      cancelled = true;
    };
  }, [sort]);

  useEffect(() => load(), [load]);

  // Filter chips: fixed filters + the most common tags in the feed,
  // deduped against built-ins. Identified by stable ids so async chips
  // (For you / Following) appearing never shifts the active selection.
  const chips = useMemo<Chip[]>(() => {
    const counts = new Map<string, number>();
    for (const r of recipes ?? []) {
      for (const t of r.tags) counts.set(t, (counts.get(t) ?? 0) + 1);
    }
    const topTags = [...counts.entries()]
      .filter(([t]) => !BUILTIN_TAG_LABELS.has(t.toLowerCase()))
      .sort((a, b) => b[1] - a[1])
      .slice(0, 6)
      .map(([t]) => t);

    const list: Chip[] = [{ id: "all", kind: "all", label: "All" }];
    if (profile?.preferences?.diets?.length) {
      list.push({ id: "foryou", kind: "foryou", label: "✨ For you" });
    }
    if (followedIds.size > 0) {
      list.push({ id: "following", kind: "following", label: "Following" });
    }
    list.push(
      { id: "time20", kind: "time", label: "Under 20 min", maxMinutes: 20 },
      { id: "cal500", kind: "cal", label: "Low-cal", maxCalories: 500 },
      {
        id: "protein30",
        kind: "protein",
        label: "High-protein",
        minProtein: 30,
      },
      { id: "time45", kind: "time", label: "Under 45 min", maxMinutes: 45 },
      ...topTags.map((t): Chip => ({
        id: tagChipId(t),
        kind: "tag",
        label: t,
      })),
    );

    // A deep-linked tag that isn't in the top tags still gets a chip.
    if (
      tagParam &&
      !BUILTIN_TAG_LABELS.has(tagParam.toLowerCase()) &&
      !list.some((c) => c.id === tagChipId(tagParam))
    ) {
      list.push({ id: tagChipId(tagParam), kind: "tag", label: tagParam });
    }
    return list;
  }, [recipes, profile, followedIds, tagParam]);

  const activeChip = chips.find((c) => c.id === activeChipId) ?? chips[0];

  const pickChip = (chip: Chip) => {
    setActiveChipId(chip.id);
    // Manual picks replace any deep-linked tag in the URL.
    if (tagParam) setParams({}, { replace: true });
    // Make the filtered set obvious when the user is mid-scroll.
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const filtered = useMemo(() => {
    if (!recipes) return null;
    return filterFeedRecipes(
      recipes,
      search,
      toFeedChip(activeChip),
      profile?.preferences?.diets ?? [],
      followedIds,
    );
  }, [recipes, search, activeChip, profile, followedIds]);

  const filteredEmpty = filtered !== null && filtered.length === 0;
  const isForYouEmpty = filteredEmpty && activeChip.kind === "foryou";

  return (
    <div className="mx-auto max-w-lg px-4 pt-safe pb-nav">
      {/* Header */}
      {/* Double-tap header to toggle debug overlay */}
      <header
        className="flex items-end justify-between pt-6 pb-4"
        onDoubleClick={() => setShowDebugInfo((v) => !v)}
      >
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

      {/* Debug overlay: double-tap header to toggle — shows mode, recipe count */}
      {showDebugInfo && (
        <div className="mb-4 rounded-lg border border-dashed p-3 text-xs text-muted">
          <div className="font-bold mb-1">Debug Info</div>
          <div>Sort: {sort}</div>
          <div>Profile: {profile?.username ?? "(not signed in)"}</div>
          <div>Recipes loaded: {recipes?.length ?? "—"}</div>
          <div>Error: {error ?? "(none)"}</div>
        </div>
      )}

      {showTasteNudge && (
        <div className="mb-4 flex items-start gap-3 rounded-2xl border border-accent/25 bg-accent-soft p-4">
          <Sparkles size={18} className="mt-0.5 shrink-0 text-accent" />
          <div className="min-w-0 flex-1">
            <p className="text-[14px] font-extrabold text-content">
              Make recipes adapt to you
            </p>
            <p className="mt-0.5 text-[13px] leading-snug text-muted">
              Set diets and allergies once — we treat allergies as a hard safety
              rule on every AI generate.
            </p>
            <div className="mt-3 flex flex-wrap gap-2">
              <Link
                to="/taste"
                onClick={() => localStorage.setItem(TASTE_NUDGE_KEY, "1")}
                className="pressable rounded-full bg-content px-4 py-1.5 text-[13px] font-bold text-surface"
              >
                Set taste profile
              </Link>
              <button
                type="button"
                onClick={() => {
                  localStorage.setItem(TASTE_NUDGE_KEY, "1");
                  setShowTasteNudge(false);
                }}
                className="pressable rounded-full px-3 py-1.5 text-[13px] font-bold text-muted"
              >
                Not now
              </button>
            </div>
          </div>
        </div>
      )}

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
          {chips.map((c) => (
            <button
              key={c.id}
              onClick={() => pickChip(c)}
              className={`pressable shrink-0 rounded-full px-4 py-1.5 text-[13px] font-bold whitespace-nowrap transition-colors ${
                c.id === activeChip.id
                  ? "bg-content text-surface"
                  : "border border-line bg-raised text-muted"
              }`}
            >
              {c.label}
            </button>
          ))}
        </div>
        {/* Confirms a filter took effect even when the top card doesn't
            change (e.g. one recipe qualifying for several filters). */}
        {filtered !== null && (activeChip.id !== "all" || search) && (
          <p className="px-1 text-xs font-semibold text-faint">
            {filtered.length} {filtered.length === 1 ? "recipe" : "recipes"}
          </p>
        )}
      </div>

      {/* Error state — shows actual error message from the API */}
      {error && (
        <EmptyState
          emoji="📡"
          title="Connection hiccup"
          body={error}
          action={
            <button
              onClick={load}
              className="pressable rounded-full bg-content px-5 py-2 text-sm font-bold text-surface"
            >
              Retry
            </button>
          }
        />
      )}

      {!error && filtered === null && <FeedSkeleton />}

      {!error && isForYouEmpty && (
        <EmptyState
          emoji="🥗"
          title="Nothing matches your diets yet"
          body={`No community recipes are tagged ${(profile?.preferences?.diets ?? []).join(" or ")} right now — generate one and the AI will cook to your taste profile automatically.`}
          action={
            <Link
              to="/create"
              className="pressable rounded-full bg-content px-5 py-2 text-sm font-bold text-surface"
            >
              Generate one for my diet
            </Link>
          }
        />
      )}

      {!error &&
        filteredEmpty &&
        !isForYouEmpty &&
        activeChip.kind === "following" && (
          <EmptyState
            emoji="👥"
            title="No recipes from chefs you follow"
            body="Follow a chef from any recipe page — their new dishes show up here."
            action={
              <button
                type="button"
                onClick={() => pickChip({ id: "all", kind: "all", label: "All" })}
                className="pressable rounded-full bg-content px-5 py-2 text-sm font-bold text-surface"
              >
                Browse Hot recipes
              </button>
            }
          />
        )}

      {!error &&
        filteredEmpty &&
        !isForYouEmpty &&
        activeChip.kind !== "following" && (
        <EmptyState
          emoji={search || activeChip.kind !== "all" ? "🔍" : "🍳"}
          title={
            search || activeChip.kind !== "all"
              ? "No matches"
              : "Nothing cooking yet"
          }
          body={
            search || activeChip.kind !== "all"
              ? "Try a different search or filter — or generate exactly what you're craving."
              : "Be the first — describe what you're craving and let the AI take it from there."
          }
          action={
            search || activeChip.kind !== "all" ? (
              <button
                type="button"
                onClick={() => {
                  setSearch("");
                  pickChip({ id: "all", kind: "all", label: "All" });
                }}
                className="pressable rounded-full bg-content px-5 py-2 text-sm font-bold text-surface"
              >
                Clear filters & browse
              </button>
            ) : (
              <Link
                to="/create"
                className="pressable rounded-full bg-content px-5 py-2 text-sm font-bold text-surface"
              >
                Generate a recipe
              </Link>
            )
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
