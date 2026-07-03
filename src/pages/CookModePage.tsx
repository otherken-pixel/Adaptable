import { useEffect, useMemo, useRef, useState } from "react";
import { Link, useNavigate, useParams, useSearchParams } from "react-router-dom";
import {
  Check,
  ChevronLeft,
  ChevronRight,
  Lightbulb,
  ListChecks,
  PartyPopper,
  X,
} from "lucide-react";
import { fetchRecipe } from "@/lib/api";
import { extractTimerSeconds } from "@/lib/duration";
import { scaleQuantity } from "@/lib/quantity";
import { coverGradient } from "@/lib/gradients";
import type { Recipe } from "@/lib/types";
import StepTimer from "@/components/StepTimer";
import VotePill from "@/components/VotePill";
import SaveButton from "@/components/SaveButton";

/**
 * Full-screen guided cooking: one step at a time in huge type, one-tap
 * timers parsed from the instructions, an ingredients sheet always a tap
 * away, and a screen wake-lock so the phone never sleeps mid-sauté.
 */
export default function CookModePage() {
  const { id } = useParams<{ id: string }>();
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const [recipe, setRecipe] = useState<Recipe | null>(null);
  // 0 = mise en place, 1..N = steps, N+1 = done
  const [idx, setIdx] = useState(0);
  const [gathered, setGathered] = useState<Set<number>>(new Set());
  const [sheetOpen, setSheetOpen] = useState(false);

  const servings = Number(params.get("servings")) || undefined;
  const factor = recipe && servings ? servings / recipe.servings : 1;

  useEffect(() => {
    if (!id) return;
    let cancelled = false;
    fetchRecipe(id)
      .then((r) => !cancelled && setRecipe(r))
      .catch(() => !cancelled && setRecipe(null));
    return () => {
      cancelled = true;
    };
  }, [id]);

  // Keep the screen awake while cooking.
  const wakeLockRef = useRef<{ release: () => Promise<void> } | null>(null);
  useEffect(() => {
    const nav = navigator as Navigator & {
      wakeLock?: { request: (type: "screen") => Promise<{ release: () => Promise<void> }> };
    };
    let active = true;
    const acquire = () => {
      nav.wakeLock
        ?.request("screen")
        .then((lock) => {
          if (active) wakeLockRef.current = lock;
          else void lock.release();
        })
        .catch(() => {
          /* wake lock denied — cook mode still works */
        });
    };
    acquire();
    const onVisible = () => {
      if (document.visibilityState === "visible") acquire();
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      active = false;
      document.removeEventListener("visibilitychange", onVisible);
      void wakeLockRef.current?.release().catch(() => {});
    };
  }, []);

  const steps = recipe?.steps ?? [];
  const total = steps.length;
  const timerSeconds = useMemo(() => {
    if (idx < 1 || idx > total) return null;
    return extractTimerSeconds(steps[idx - 1].instruction);
  }, [idx, steps, total]);

  if (!recipe) {
    return (
      <div className="flex min-h-dvh items-center justify-center bg-surface">
        <div className="skeleton h-24 w-64 rounded-card" />
      </div>
    );
  }

  const exit = () => navigate(`/recipe/${recipe.id}`);
  const isPrep = idx === 0;
  const isDone = idx === total + 1;
  const step = !isPrep && !isDone ? steps[idx - 1] : null;

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-surface">
      {/* Top bar */}
      <div className="pt-safe">
        <div className="mx-auto flex max-w-lg items-center gap-3 px-4 pt-3 pb-2">
          <button
            aria-label="Exit cook mode"
            onClick={exit}
            className="pressable flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-sunken text-muted"
          >
            <X size={20} strokeWidth={2.4} />
          </button>
          <div className="flex min-w-0 flex-1 flex-col gap-1.5">
            <p className="truncate text-center text-[13px] font-bold">
              {recipe.emoji} {recipe.title}
            </p>
            <div className="flex gap-1">
              {Array.from({ length: total + 1 }).map((_, i) => (
                <span
                  key={i}
                  className="h-1 flex-1 rounded-full transition-colors"
                  style={{
                    background: i <= idx - (isDone ? 1 : 0) && idx > 0
                      ? "var(--accent)"
                      : "var(--line)",
                  }}
                />
              ))}
            </div>
          </div>
          <button
            aria-label="Show ingredients"
            onClick={() => setSheetOpen(true)}
            className="pressable flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-sunken text-muted"
          >
            <ListChecks size={19} strokeWidth={2.2} />
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="mx-auto w-full max-w-lg flex-1 overflow-y-auto px-5">
        {isPrep && (
          <div className="animate-fade-up py-4" key="prep">
            <p className="text-xs font-bold tracking-[0.18em] text-accent uppercase">
              Mise en place
            </p>
            <h2 className="mt-2 text-[28px] leading-tight font-extrabold tracking-tight">
              Gather everything first
            </h2>
            <p className="mt-2 text-[15px] text-muted">
              {servings && servings !== recipe.servings
                ? `Scaled for ${servings} servings.`
                : `For ${recipe.servings} servings.`}{" "}
              Tap items as you set them out.
            </p>
            <div className="mt-5 overflow-hidden rounded-card border border-line bg-raised">
              {recipe.ingredients.map((ing, i) => {
                const done = gathered.has(i);
                return (
                  <button
                    key={i}
                    onClick={() =>
                      setGathered((prev) => {
                        const next = new Set(prev);
                        if (next.has(i)) next.delete(i);
                        else next.add(i);
                        return next;
                      })
                    }
                    className={`flex w-full items-center gap-3 px-4 py-3.5 text-left transition-opacity ${
                      i > 0 ? "border-t border-line" : ""
                    } ${done ? "opacity-45" : ""}`}
                  >
                    <span
                      className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full border-2 transition-colors ${
                        done ? "border-accent bg-accent text-white" : "border-line"
                      }`}
                    >
                      {done && <Check size={14} strokeWidth={3} className="animate-pop" />}
                    </span>
                    <span className={`flex-1 text-[15px] font-semibold ${done ? "line-through" : ""}`}>
                      {ing.item}
                    </span>
                    <span className="text-sm font-bold text-muted tabular-nums">
                      {scaleQuantity(ing.quantity, factor)}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {step && (
          <div className="animate-fade-up py-4" key={`step-${idx}`}>
            <p className="text-xs font-bold tracking-[0.18em] text-accent uppercase">
              Step {idx} of {total}
            </p>
            <p className="mt-4 text-[26px] leading-snug font-bold tracking-tight">
              {step.instruction}
            </p>
            {step.tip && (
              <div className="mt-5 flex items-start gap-2.5 rounded-2xl bg-accent-soft px-4 py-3">
                <Lightbulb size={16} className="mt-0.5 shrink-0 text-accent" />
                <p className="text-sm leading-relaxed font-medium text-accent">
                  {step.tip}
                </p>
              </div>
            )}
            {timerSeconds && (
              <div className="mt-5">
                <StepTimer key={idx} seconds={timerSeconds} />
              </div>
            )}
          </div>
        )}

        {isDone && (
          <div className="relative flex flex-col items-center py-10 text-center" key="done">
            <Confetti />
            <div
              className="animate-pop flex h-24 w-24 items-center justify-center rounded-full text-white shadow-xl shadow-accent/30"
              style={{ background: coverGradient(recipe.id) }}
            >
              <PartyPopper size={44} strokeWidth={1.8} />
            </div>
            <h2 className="mt-6 text-[28px] font-extrabold tracking-tight">
              Chef's kiss! 🤌
            </h2>
            <p className="mt-2 max-w-64 text-[15px] leading-relaxed text-muted">
              You just cooked <strong>{recipe.title}</strong>. How did it turn
              out? Your vote shapes the community feed.
            </p>
            <div className="mt-7 flex w-full max-w-xs items-center gap-3">
              <VotePill recipeId={recipe.id} baseCount={recipe.net_upvotes} size="lg" />
              <SaveButton recipeId={recipe.id} variant="bar" />
            </div>
            <Link
              to="/"
              className="pressable mt-4 text-sm font-bold text-muted underline-offset-4 hover:underline"
            >
              Back to Discover
            </Link>
          </div>
        )}
      </div>

      {/* Bottom controls */}
      {!isDone && (
        <div className="pb-safe">
          <div className="mx-auto flex max-w-lg items-center gap-3 px-5 pt-2 pb-4">
            {idx > 0 && (
              <button
                aria-label="Previous step"
                onClick={() => setIdx((i) => i - 1)}
                className="pressable flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl border border-line bg-raised text-muted"
              >
                <ChevronLeft size={24} strokeWidth={2.4} />
              </button>
            )}
            <button
              onClick={() => setIdx((i) => i + 1)}
              className="pressable flex h-14 flex-1 items-center justify-center gap-2 rounded-2xl text-[16px] font-extrabold text-white shadow-lg shadow-accent/25"
              style={{
                background:
                  "linear-gradient(135deg, #fb923c 0%, #ea580c 60%, #dc2626 130%)",
              }}
            >
              {isPrep ? "Let's cook" : idx === total ? "Finish 🎉" : "Next step"}
              {!isPrep && idx < total && <ChevronRight size={20} strokeWidth={2.6} />}
            </button>
          </div>
        </div>
      )}

      {/* Ingredients sheet */}
      {sheetOpen && (
        <div
          className="absolute inset-0 z-10 flex flex-col justify-end bg-black/45"
          onClick={() => setSheetOpen(false)}
        >
          <div
            className="animate-fade-up max-h-[70%] overflow-y-auto rounded-t-[28px] bg-surface p-5 pb-safe"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="mx-auto mb-4 h-1.5 w-10 rounded-full bg-line" />
            <h3 className="text-lg font-extrabold tracking-tight">Ingredients</h3>
            <div className="mt-3 mb-4 overflow-hidden rounded-card border border-line bg-raised">
              {recipe.ingredients.map((ing, i) => (
                <div
                  key={i}
                  className={`flex items-center justify-between gap-3 px-4 py-3 ${
                    i > 0 ? "border-t border-line" : ""
                  }`}
                >
                  <span className="text-[15px] font-semibold">{ing.item}</span>
                  <span className="text-sm font-bold text-muted tabular-nums">
                    {scaleQuantity(ing.quantity, factor)}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

const CONFETTI_COLORS = ["#fb923c", "#f43f5e", "#22c55e", "#3b82f6", "#eab308", "#a855f7"];

function Confetti() {
  const pieces = useMemo(
    () =>
      Array.from({ length: 46 }, (_, i) => ({
        left: Math.random() * 100,
        delay: Math.random() * 0.9,
        duration: 2.4 + Math.random() * 1.8,
        color: CONFETTI_COLORS[i % CONFETTI_COLORS.length],
        size: 6 + Math.random() * 6,
        rot: Math.random() * 360,
      })),
    [],
  );
  return (
    <div className="pointer-events-none fixed inset-0 overflow-hidden">
      {pieces.map((p, i) => (
        <span
          key={i}
          className="absolute top-0 block"
          style={{
            left: `${p.left}%`,
            width: p.size,
            height: p.size * 0.45,
            background: p.color,
            borderRadius: 2,
            transform: `rotate(${p.rot}deg)`,
            animation: `confetti-fall ${p.duration}s cubic-bezier(0.25,0.46,0.45,0.94) ${p.delay}s both`,
          }}
        />
      ))}
    </div>
  );
}
