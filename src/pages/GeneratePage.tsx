import { useEffect, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import {
  ArrowUp,
  ChefHat,
  Plus,
  Refrigerator,
  RotateCcw,
  Shuffle,
  Sparkles,
  Wand2,
  X,
} from "lucide-react";
import { fetchRecipe, generateRecipe } from "@/lib/api";
import type { Recipe } from "@/lib/types";
import RecipeView from "@/components/RecipeView";

const SUGGESTIONS = [
  "High-protein vegan dinner in 20 minutes 💪",
  "Date night pasta, restaurant-level 🕯️",
  "Something cozy with what's in my pantry 🫘",
  "Kid-friendly hidden-veggie dinner 🥦",
  "Spicy 15-minute noodles 🌶️",
  "Impressive dessert, minimal effort 🍫",
];

const REMIX_SUGGESTIONS = [
  "Make it vegan 🌱",
  "Gluten-free version 🌾",
  "Twice as spicy 🔥",
  "Halve the cook time ⏱️",
  "Budget-friendly swaps 💸",
  "Air-fryer version 💨",
];

const PANTRY_STAPLES = [
  "Eggs",
  "Rice",
  "Pasta",
  "Chicken",
  "Canned tomatoes",
  "Onions",
  "Garlic",
  "Potatoes",
  "Black beans",
  "Cheese",
  "Tortillas",
  "Frozen spinach",
];

type CreateMode = "describe" | "pantry";

const LOADING_LINES = [
  "Reading your cravings…",
  "Raiding the flavor archives…",
  "Balancing the macros…",
  "Sharpening the knives…",
  "Taste-testing (mentally)…",
  "Plating it beautifully…",
];

type Phase = "idle" | "loading" | "done" | "error";

export default function GeneratePage() {
  const [prompt, setPrompt] = useState("");
  const [phase, setPhase] = useState<Phase>("idle");
  const [recipe, setRecipe] = useState<Recipe | null>(null);
  const [errorMsg, setErrorMsg] = useState("");
  const [lineIdx, setLineIdx] = useState(0);
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const topRef = useRef<HTMLDivElement>(null);

  // Pantry flow: pick what's in the fridge, we figure out the dish.
  const [mode, setMode] = useState<CreateMode>("describe");
  const [pantry, setPantry] = useState<string[]>([]);
  const [pantryDraft, setPantryDraft] = useState("");

  const addPantryItem = (raw: string) => {
    const item = raw.trim();
    if (!item) return;
    setPantry((prev) =>
      prev.some((p) => p.toLowerCase() === item.toLowerCase())
        ? prev
        : [...prev, item],
    );
    setPantryDraft("");
  };

  const cookFromPantry = () => {
    if (pantry.length < 2) return;
    void submit(
      `What can I make with what I have on hand: ${pantry.join(", ")}? ` +
        "Use mainly these ingredients (basic staples like oil, salt, pepper and water are available). " +
        "Minimize anything I'd need to buy.",
    );
  };

  // Remix flow: /create?remix=<recipeId> adapts an existing recipe.
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const remixId = params.get("remix");
  const [remixSource, setRemixSource] = useState<Recipe | null>(null);

  useEffect(() => {
    if (!remixId) {
      setRemixSource(null);
      return;
    }
    let cancelled = false;
    fetchRecipe(remixId)
      .then((r) => !cancelled && setRemixSource(r))
      .catch(() => !cancelled && setRemixSource(null));
    return () => {
      cancelled = true;
    };
  }, [remixId]);

  useEffect(() => {
    if (phase !== "loading") return;
    setLineIdx(0);
    const t = setInterval(
      () => setLineIdx((i) => (i + 1) % LOADING_LINES.length),
      1400,
    );
    return () => clearInterval(t);
  }, [phase]);

  const submit = async (text?: string) => {
    const p = (text ?? prompt).trim();
    if (!p || phase === "loading") return;
    setPrompt(p);
    setPhase("loading");
    setRecipe(null);
    topRef.current?.scrollIntoView({ behavior: "smooth" });
    try {
      let apiPrompt = p;
      if (remixSource) {
        const ingredientList = remixSource.ingredients
          .slice(0, 10)
          .map((i) => i.item)
          .join(", ");
        apiPrompt =
          `Adapt the recipe "${remixSource.title}" (key ingredients: ${ingredientList}). ` +
          `Requested change: ${p}`.slice(0, 480);
      }
      const result = await generateRecipe(apiPrompt);
      setRecipe(result);
      setPhase("done");
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : "Something went wrong.");
      setPhase("error");
    }
  };

  const reset = () => {
    setPhase("idle");
    setRecipe(null);
    setPrompt("");
    if (remixId) navigate("/create", { replace: true });
    inputRef.current?.focus();
  };

  return (
    <div className="mx-auto max-w-lg px-4 pt-safe pb-nav">
      <div ref={topRef} />
      <header className="pt-6 pb-4">
        <p className="text-xs font-bold tracking-[0.18em] text-accent uppercase">
          AI Chef
        </p>
        <h1 className="mt-1 text-[32px] leading-none font-extrabold tracking-tight">
          Create
        </h1>
      </header>

      {phase === "idle" && (
        <div className="animate-fade-up">
          {remixSource ? (
            <div className="mb-5 flex items-center gap-3 rounded-card border border-line bg-raised p-4">
              <span className="text-4xl">{remixSource.emoji}</span>
              <div className="min-w-0 flex-1">
                <p className="flex items-center gap-1.5 text-xs font-bold tracking-wide text-accent uppercase">
                  <Shuffle size={12} strokeWidth={2.6} /> Remixing
                </p>
                <p className="truncate text-[15px] font-extrabold">
                  {remixSource.title}
                </p>
              </div>
              <button
                aria-label="Cancel remix"
                onClick={() => navigate("/create", { replace: true })}
                className="pressable flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-sunken text-muted"
              >
                <X size={15} strokeWidth={2.4} />
              </button>
            </div>
          ) : (
            <>
              {/* Describe ↔ Pantry mode toggle */}
              <div className="mx-auto flex w-fit rounded-full bg-sunken p-1">
                {(
                  [
                    { id: "describe", label: "Describe it", icon: Wand2 },
                    { id: "pantry", label: "What's in my fridge", icon: Refrigerator },
                  ] as const
                ).map(({ id, label, icon: Icon }) => (
                  <button
                    key={id}
                    onClick={() => setMode(id)}
                    className={`pressable flex items-center gap-1.5 rounded-full px-4 py-2 text-[13px] font-bold whitespace-nowrap transition-colors ${
                      mode === id ? "bg-raised text-content shadow-sm" : "text-muted"
                    }`}
                  >
                    <Icon size={14} strokeWidth={2.4} />
                    {label}
                  </button>
                ))}
              </div>

              {mode === "describe" && (
                <div className="flex flex-col items-center pt-8 pb-10 text-center">
                  <div
                    className="flex h-20 w-20 animate-float items-center justify-center rounded-3xl shadow-xl shadow-accent/25"
                    style={{
                      background:
                        "linear-gradient(135deg, #fb923c 0%, #ea580c 55%, #dc2626 120%)",
                    }}
                  >
                    <ChefHat size={38} className="text-white" strokeWidth={2} />
                  </div>
                  <h2 className="mt-5 text-xl font-extrabold tracking-tight">
                    What are we cooking tonight?
                  </h2>
                  <p className="mt-2 max-w-72 text-sm leading-relaxed text-muted">
                    Describe cravings, constraints, time limits or whatever's in
                    the fridge — get a complete recipe in seconds.
                  </p>
                </div>
              )}
            </>
          )}

          {(remixSource || mode === "describe") && (
            <>
              <p className="mb-2 text-xs font-bold tracking-wide text-faint uppercase">
                {remixSource ? "How should we change it?" : "Try one of these"}
              </p>
              <div className="flex flex-wrap gap-2">
                {(remixSource ? REMIX_SUGGESTIONS : SUGGESTIONS).map((s) => (
                  <button
                    key={s}
                    onClick={() => submit(s)}
                    className="pressable rounded-full border border-line bg-raised px-4 py-2.5 text-left text-[13px] leading-snug font-semibold shadow-sm"
                  >
                    {s}
                  </button>
                ))}
              </div>
            </>
          )}

          {!remixSource && mode === "pantry" && (
            <div className="pt-6">
              <h2 className="text-xl font-extrabold tracking-tight">
                What's in the fridge? 🧺
              </h2>
              <p className="mt-1.5 text-sm leading-relaxed text-muted">
                Pick at least two ingredients and the AI builds the best
                possible dish around them — no store run required.
              </p>

              {/* Selected items */}
              {pantry.length > 0 && (
                <div className="mt-4 flex flex-wrap gap-2">
                  {pantry.map((item) => (
                    <button
                      key={item}
                      onClick={() =>
                        setPantry((prev) => prev.filter((p) => p !== item))
                      }
                      className="pressable flex items-center gap-1.5 rounded-full bg-accent-soft px-3.5 py-2 text-[13px] font-bold text-accent"
                    >
                      {item}
                      <X size={13} strokeWidth={2.8} />
                    </button>
                  ))}
                </div>
              )}

              {/* Add custom item */}
              <div className="mt-4 flex items-center gap-2 rounded-2xl border border-line bg-raised p-1.5 pl-4">
                <input
                  value={pantryDraft}
                  onChange={(e) => setPantryDraft(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") {
                      e.preventDefault();
                      addPantryItem(pantryDraft);
                    }
                  }}
                  maxLength={40}
                  placeholder="Add an ingredient…"
                  className="h-10 min-w-0 flex-1 bg-transparent text-[15px] outline-none placeholder:text-faint"
                />
                <button
                  aria-label="Add ingredient"
                  onClick={() => addPantryItem(pantryDraft)}
                  disabled={!pantryDraft.trim()}
                  className="pressable flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-sunken text-muted disabled:opacity-30"
                >
                  <Plus size={17} strokeWidth={2.6} />
                </button>
              </div>

              {/* Staples quick-add */}
              <p className="mt-5 mb-2 text-xs font-bold tracking-wide text-faint uppercase">
                Quick add
              </p>
              <div className="flex flex-wrap gap-2">
                {PANTRY_STAPLES.filter(
                  (s) => !pantry.some((p) => p.toLowerCase() === s.toLowerCase()),
                ).map((s) => (
                  <button
                    key={s}
                    onClick={() => addPantryItem(s)}
                    className="pressable rounded-full border border-line bg-raised px-3.5 py-2 text-[13px] font-semibold shadow-sm"
                  >
                    + {s}
                  </button>
                ))}
              </div>

              <button
                onClick={cookFromPantry}
                disabled={pantry.length < 2}
                className="pressable mt-6 flex h-14 w-full items-center justify-center gap-2 rounded-2xl text-[16px] font-extrabold text-white shadow-lg shadow-accent/25 transition-opacity disabled:opacity-40"
                style={{
                  background:
                    "linear-gradient(135deg, #fb923c 0%, #ea580c 60%, #dc2626 130%)",
                }}
              >
                <Sparkles size={19} strokeWidth={2.2} />
                {pantry.length < 2
                  ? "Pick at least 2 ingredients"
                  : `What can I make? (${pantry.length} items)`}
              </button>
            </div>
          )}
        </div>
      )}

      {phase === "loading" && (
        <div className="animate-fade-up">
          <div className="flex flex-col items-center pt-10 pb-8 text-center">
            <div className="relative">
              <div
                className="flex h-20 w-20 items-center justify-center rounded-3xl"
                style={{
                  background:
                    "linear-gradient(135deg, #fb923c 0%, #ea580c 55%, #dc2626 120%)",
                }}
              >
                <Sparkles size={34} className="animate-pulse text-white" />
              </div>
              <span className="absolute -inset-2 -z-10 animate-ping rounded-[28px] bg-accent/20" />
            </div>
            <p key={lineIdx} className="animate-fade-up mt-6 text-[15px] font-bold">
              {LOADING_LINES[lineIdx]}
            </p>
            <p className="mt-1 max-w-64 truncate text-xs text-faint">“{prompt}”</p>
          </div>
          <div className="overflow-hidden rounded-card border border-line bg-raised">
            <div className="skeleton h-48" />
            <div className="space-y-3 p-4">
              <div className="skeleton h-6 w-2/3 rounded-lg" />
              <div className="skeleton h-4 w-full rounded-lg" />
              <div className="skeleton h-4 w-5/6 rounded-lg" />
              <div className="flex gap-2 pt-1">
                <div className="skeleton h-7 w-20 rounded-full" />
                <div className="skeleton h-7 w-16 rounded-full" />
                <div className="skeleton h-7 w-24 rounded-full" />
              </div>
            </div>
          </div>
        </div>
      )}

      {phase === "error" && (
        <div className="animate-fade-up flex flex-col items-center pt-14 text-center">
          <span className="text-6xl">🫠</span>
          <h2 className="mt-4 text-lg font-extrabold">The kitchen hit a snag</h2>
          <p className="mt-2 max-w-72 text-sm leading-relaxed text-muted">{errorMsg}</p>
          <button
            onClick={() => submit()}
            className="pressable mt-5 rounded-full bg-content px-6 py-2.5 text-sm font-bold text-surface"
          >
            Try again
          </button>
        </div>
      )}

      {phase === "done" && recipe && (
        <>
          <div className="mb-4 flex items-center justify-between rounded-2xl bg-accent-soft px-4 py-3">
            <p className="text-[13px] font-bold text-accent">
              ✨ Fresh out of the AI kitchen — it's live on the feed
            </p>
            <button
              onClick={reset}
              className="pressable flex shrink-0 items-center gap-1.5 rounded-full bg-raised px-3 py-1.5 text-xs font-bold shadow-sm"
            >
              <RotateCcw size={13} strokeWidth={2.4} />
              New
            </button>
          </div>
          <RecipeView recipe={recipe} />
        </>
      )}

      {/* Composer — pinned above the bottom nav (pantry mode has its own CTA) */}
      {(phase === "idle" || phase === "error") &&
        (phase === "error" || mode === "describe" || remixSource !== null) && (
        <div
          className="fixed inset-x-0 z-30"
          style={{ bottom: "calc(64px + env(safe-area-inset-bottom))" }}
        >
          <div className="mx-auto max-w-lg px-4 pb-3">
            <div className="flex items-end gap-2 rounded-[26px] border border-line bg-raised p-2 shadow-[0_8px_32px_rgb(0_0_0/0.12)]">
              <textarea
                ref={inputRef}
                value={prompt}
                onChange={(e) => setPrompt(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    submit();
                  }
                }}
                rows={1}
                maxLength={500}
                placeholder="Describe your perfect meal…"
                className="max-h-28 min-h-[44px] flex-1 resize-none bg-transparent px-3 py-2.5 text-[15px] outline-none placeholder:text-faint"
              />
              <button
                aria-label="Generate recipe"
                onClick={() => submit()}
                disabled={!prompt.trim()}
                className="pressable flex h-11 w-11 shrink-0 items-center justify-center rounded-full text-white shadow-md transition-opacity disabled:opacity-30"
                style={{
                  background:
                    "linear-gradient(135deg, #fb923c 0%, #ea580c 60%, #dc2626 130%)",
                }}
              >
                <ArrowUp size={20} strokeWidth={2.6} />
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
