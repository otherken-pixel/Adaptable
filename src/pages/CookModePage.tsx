import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  Link,
  useNavigate,
  useParams,
  useSearchParams,
} from "react-router-dom";
import {
  Camera,
  Check,
  ChevronLeft,
  ChevronRight,
  Lightbulb,
  ListChecks,
  Loader2,
  Mic,
  MicOff,
  PartyPopper,
  Play,
  RotateCcw,
  TimerIcon,
  X,
} from "lucide-react";
import { fetchRecipe, recordCook, uploadCookPhoto } from "@/lib/api";
import { extractTimerSeconds, formatClock } from "@/lib/duration";
import { scaleQuantity } from "@/lib/quantity";
import { coverGradient } from "@/lib/gradients";
import { compactCount } from "@/lib/format";
import { ringAlarm } from "@/lib/alarm";
import type { Recipe } from "@/lib/types";
import { useAuth } from "@/context/AuthContext";
import VotePill from "@/components/VotePill";
import SaveButton from "@/components/SaveButton";

interface RunningTimer {
  step: number;
  endsAt: number;
  totalSeconds: number;
  rang: boolean;
}

// Minimal SpeechRecognition surface (typed loosely; vendor-prefixed on iOS).
interface SpeechRecognitionLike {
  continuous: boolean;
  interimResults: boolean;
  lang: string;
  onresult:
    | ((event: {
        results: ArrayLike<ArrayLike<{ transcript: string }>>;
        resultIndex: number;
      }) => void)
    | null;
  onend: (() => void) | null;
  onerror: (() => void) | null;
  start: () => void;
  stop: () => void;
}

function getSpeechRecognition(): (new () => SpeechRecognitionLike) | null {
  const w = window as unknown as {
    SpeechRecognition?: new () => SpeechRecognitionLike;
    webkitSpeechRecognition?: new () => SpeechRecognitionLike;
  };
  return w.SpeechRecognition ?? w.webkitSpeechRecognition ?? null;
}

/**
 * Full-screen guided cooking: one step at a time in huge type, timers
 * that keep running while you move between steps, hands-free voice
 * commands ("next", "back", "ingredients", "start timer"), a wake-lock,
 * and a celebration that records the cook and invites a photo.
 */
export default function CookModePage() {
  const { id } = useParams<{ id: string }>();
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const { profile, isDemo } = useAuth();
  const [recipe, setRecipe] = useState<Recipe | null>(null);
  // 0 = mise en place, 1..N = steps, N+1 = done
  const [idx, setIdx] = useState(0);
  const [gathered, setGathered] = useState<Set<number>>(new Set());
  const [sheetOpen, setSheetOpen] = useState(false);
  const cookRecordedRef = useRef(false);

  // Multi-timer state — timers survive step navigation.
  const [timers, setTimers] = useState<RunningTimer[]>([]);
  const [now, setNow] = useState(Date.now());

  // Cooked-it photo (live mode only)
  const photoInputRef = useRef<HTMLInputElement>(null);
  const [photoState, setPhotoState] = useState<"idle" | "uploading" | "done">(
    "idle",
  );

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

  // Tick while any timer is live; ring exactly once per finished timer.
  useEffect(() => {
    if (timers.length === 0) return;
    const t = setInterval(() => {
      setNow(Date.now());
      setTimers((prev) => {
        let changed = false;
        const next = prev.map((tm) => {
          if (!tm.rang && tm.endsAt <= Date.now()) {
            changed = true;
            ringAlarm();
            return { ...tm, rang: true };
          }
          return tm;
        });
        return changed ? next : prev;
      });
    }, 400);
    return () => clearInterval(t);
  }, [timers.length]);

  // Keep the screen awake while cooking.
  const wakeLockRef = useRef<{ release: () => Promise<void> } | null>(null);
  useEffect(() => {
    const nav = navigator as Navigator & {
      wakeLock?: {
        request: (type: "screen") => Promise<{ release: () => Promise<void> }>;
      };
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

  // Reaching the finish screen counts as "Cooked it" — once per session.
  const reachedDone = recipe !== null && idx === total + 1;
  useEffect(() => {
    if (reachedDone && profile && recipe && !cookRecordedRef.current) {
      cookRecordedRef.current = true;
      recordCook(profile.id, recipe.id).catch(() => {
        /* trending signal only — never block the celebration */
      });
    }
  }, [reachedDone, profile, recipe]);

  const currentTimerSeconds = useMemo(() => {
    if (idx < 1 || idx > total) return null;
    return extractTimerSeconds(steps[idx - 1].instruction);
  }, [idx, steps, total]);

  const currentTimer = timers.find((t) => t.step === idx) ?? null;

  const startTimer = useCallback(() => {
    if (!currentTimerSeconds || idx < 1 || idx > total) return;
    setTimers((prev) =>
      prev.some((t) => t.step === idx)
        ? prev
        : [
            ...prev,
            {
              step: idx,
              endsAt: Date.now() + currentTimerSeconds * 1000,
              totalSeconds: currentTimerSeconds,
              rang: false,
            },
          ],
    );
    setNow(Date.now());
  }, [currentTimerSeconds, idx, total]);

  const clearTimer = (step: number) =>
    setTimers((prev) => prev.filter((t) => t.step !== step));

  const goNext = useCallback(
    () => setIdx((i) => Math.min(i + 1, total + 1)),
    [total],
  );
  const goBack = useCallback(() => setIdx((i) => Math.max(i - 1, 0)), []);

  /* ---- Voice control ---- */
  const SR = useMemo(getSpeechRecognition, []);
  const [voiceOn, setVoiceOn] = useState(false);
  const actionsRef = useRef({ goNext, goBack, startTimer, setSheetOpen });
  actionsRef.current = { goNext, goBack, startTimer, setSheetOpen };

  /// Max consecutive restart attempts to prevent infinite loops if the
  /// recognition API enters a broken state (Chrome's known issue).
  const restartCountRef = useRef(0);
  const MAX_RESTARTS = 5;

  useEffect(() => {
    if (!voiceOn || !SR) return;
    let stopped = false;
    let rec: SpeechRecognitionLike | null = null;

    const startRecognition = () => {
      restartCountRef.current = 0; // Reset on fresh start
      rec = new SR();
      rec.continuous = true;
      rec.interimResults = false;
      rec.lang = "en-US";
      rec.onresult = (event) => {
        const last = event.results[event.results.length - 1];
        const heard = (last?.[0]?.transcript ?? "").toLowerCase();
        const a = actionsRef.current;
        if (/\b(next|continue|done|forward)\b/.test(heard)) a.goNext();
        else if (/\b(back|previous)\b/.test(heard)) a.goBack();
        else if (/\bingredient/.test(heard)) a.setSheetOpen(true);
        else if (/\b(close|hide)\b/.test(heard)) a.setSheetOpen(false);
        else if (/\btimer\b/.test(heard)) a.startTimer();
      };
      rec.onend = () => {
        // Browsers silently stop recognition after ~5 minutes. Restart
        // automatically but with a small delay and max attempt limit.
        if (stopped) return;
        restartCountRef.current++;
        if (restartCountRef.current > MAX_RESTARTS) {
          // Recognition API is in a broken state — give up gracefully.
          setVoiceOn(false);
          return;
        }
        // Short delay prevents rapid-fire restart loops.
        setTimeout(() => {
          if (stopped) return;
          try {
            rec?.start();
          } catch {
            /* already restarting */
          }
        }, 100 * restartCountRef.current); // Exponential-ish backoff
      };
      rec.onerror = () => {
        if (!stopped) setVoiceOn(false);
      };
      try {
        rec.start();
      } catch {
        setVoiceOn(false);
      }
    };

    startRecognition();

    return () => {
      stopped = true;
      restartCountRef.current = MAX_RESTARTS; // Prevent any more starts
      if (rec) {
        try {
          rec.stop();
        } catch {
          /* already stopped */
        }
      }
    };
  }, [voiceOn, SR]);

  const onPhotoPicked = async (file: File | null) => {
    if (!file || !profile || !recipe || photoState === "uploading") return;
    setPhotoState("uploading");
    try {
      await uploadCookPhoto(profile.id, recipe.id, file);
      setPhotoState("done");
    } catch {
      setPhotoState("idle");
    }
  };

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
  const otherTimers = timers.filter((t) => t.step !== idx);

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-surface">
      {/* Top bar */}
      <div className="pt-safe">
        <div className="mx-auto flex max-w-lg items-center gap-2 px-4 pt-3 pb-2">
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
                    background:
                      i <= idx - (isDone ? 1 : 0) && idx > 0
                        ? "var(--accent)"
                        : "var(--line)",
                  }}
                />
              ))}
            </div>
          </div>
          {SR && (
            <button
              aria-label={
                voiceOn ? "Disable voice control" : "Enable voice control"
              }
              onClick={() => setVoiceOn((v) => !v)}
              className={`pressable flex h-10 w-10 shrink-0 items-center justify-center rounded-full ${
                voiceOn ? "bg-accent text-white" : "bg-sunken text-muted"
              }`}
            >
              {voiceOn ? (
                <Mic size={18} strokeWidth={2.2} className="animate-pulse" />
              ) : (
                <MicOff size={18} strokeWidth={2.2} />
              )}
            </button>
          )}
          <button
            aria-label="Show ingredients"
            onClick={() => setSheetOpen(true)}
            className="pressable flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-sunken text-muted"
          >
            <ListChecks size={19} strokeWidth={2.2} />
          </button>
        </div>

        {/* Heads-up strip: timers running on other steps */}
        {otherTimers.length > 0 && (
          <div className="mx-auto max-w-lg px-4 pb-1">
            <div className="scrollbar-none flex gap-2 overflow-x-auto">
              {otherTimers.map((t) => {
                const left = Math.max(0, Math.round((t.endsAt - now) / 1000));
                const finished = left === 0;
                return (
                  <button
                    key={t.step}
                    onClick={() =>
                      finished ? clearTimer(t.step) : setIdx(t.step)
                    }
                    className={`pressable flex shrink-0 items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-extrabold tabular-nums ${
                      finished
                        ? "animate-pulse bg-accent text-white"
                        : "bg-accent-soft text-accent"
                    }`}
                  >
                    <TimerIcon size={12} strokeWidth={2.6} />
                    Step {t.step} · {finished ? "Done ✓" : formatClock(left)}
                  </button>
                );
              })}
            </div>
          </div>
        )}
      </div>

      {/* Content */}
      <div className="mx-auto w-full max-w-lg flex-1 overflow-y-auto px-5">
        {voiceOn && (
          <p className="animate-fade-up mt-2 rounded-xl bg-accent-soft px-3 py-2 text-center text-[12px] font-bold text-accent">
            🎙️ Listening — say “next”, “back”, “ingredients” or “start timer”
          </p>
        )}

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
                        done
                          ? "border-accent bg-accent text-white"
                          : "border-line"
                      }`}
                    >
                      {done && (
                        <Check
                          size={14}
                          strokeWidth={3}
                          className="animate-pop"
                        />
                      )}
                    </span>
                    <span
                      className={`flex-1 text-[15px] font-semibold ${done ? "line-through" : ""}`}
                    >
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

            {/* Timer for this step — keeps running if you navigate away */}
            {currentTimerSeconds && (
              <div className="mt-5 flex items-center gap-3 rounded-2xl border border-line bg-raised px-4 py-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-full bg-accent-soft">
                  <TimerIcon
                    size={17}
                    strokeWidth={2.4}
                    className="text-accent"
                  />
                </div>
                <div className="min-w-0 flex-1">
                  <p className="text-xl leading-none font-extrabold tracking-tight tabular-nums">
                    {currentTimer
                      ? formatClock(
                          Math.max(
                            0,
                            Math.round((currentTimer.endsAt - now) / 1000),
                          ),
                        )
                      : formatClock(currentTimerSeconds)}
                  </p>
                  <p className="mt-0.5 text-[11px] font-semibold text-faint">
                    {currentTimer
                      ? currentTimer.endsAt <= now
                        ? "Time's up!"
                        : "Running — keeps going between steps"
                      : "Step timer"}
                  </p>
                </div>
                {!currentTimer ? (
                  <button
                    aria-label="Start timer"
                    onClick={startTimer}
                    className="pressable flex h-11 w-11 items-center justify-center rounded-full text-white shadow-md"
                    style={{
                      background:
                        "linear-gradient(135deg, #fb923c 0%, #ea580c 60%, #dc2626 130%)",
                    }}
                  >
                    <Play
                      size={18}
                      strokeWidth={2.4}
                      fill="currentColor"
                      className="ml-0.5"
                    />
                  </button>
                ) : (
                  <button
                    aria-label="Reset timer"
                    onClick={() => clearTimer(idx)}
                    className="pressable flex h-11 w-11 items-center justify-center rounded-full border border-line bg-raised text-muted"
                  >
                    <RotateCcw size={17} strokeWidth={2.2} />
                  </button>
                )}
              </div>
            )}
          </div>
        )}

        {isDone && (
          <div
            className="relative flex flex-col items-center py-10 text-center"
            key="done"
          >
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
            <p className="mt-3 rounded-full bg-accent-soft px-4 py-1.5 text-[13px] font-bold text-accent">
              🍳 You're cook #{compactCount(recipe.cook_count + 1)} — this fuels
              the Trending feed
            </p>
            <div className="mt-7 flex w-full max-w-xs items-center gap-3">
              <VotePill
                recipeId={recipe.id}
                baseCount={recipe.net_upvotes}
                size="lg"
              />
              <SaveButton recipeId={recipe.id} variant="bar" />
            </div>

            {!isDemo && (
              <>
                <input
                  ref={photoInputRef}
                  type="file"
                  accept="image/*"
                  capture="environment"
                  className="hidden"
                  onChange={(e) =>
                    void onPhotoPicked(e.target.files?.[0] ?? null)
                  }
                />
                <button
                  onClick={() =>
                    photoState !== "done" && photoInputRef.current?.click()
                  }
                  disabled={photoState === "uploading"}
                  className={`pressable mt-4 flex h-12 w-full max-w-xs items-center justify-center gap-2 rounded-2xl border text-[14px] font-bold ${
                    photoState === "done"
                      ? "border-accent bg-accent-soft text-accent"
                      : "border-line bg-raised"
                  }`}
                >
                  {photoState === "uploading" ? (
                    <Loader2 size={16} className="animate-spin" />
                  ) : photoState === "done" ? (
                    <>
                      <Check
                        size={16}
                        strokeWidth={2.6}
                        className="animate-pop"
                      />
                      Photo shared with the community
                    </>
                  ) : (
                    <>
                      <Camera
                        size={16}
                        strokeWidth={2.2}
                        className="text-accent"
                      />
                      Show off your plate 📸
                    </>
                  )}
                </button>
              </>
            )}

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
                onClick={goBack}
                className="pressable flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl border border-line bg-raised text-muted"
              >
                <ChevronLeft size={24} strokeWidth={2.4} />
              </button>
            )}
            <button
              onClick={goNext}
              className="pressable flex h-14 flex-1 items-center justify-center gap-2 rounded-2xl text-[16px] font-extrabold text-white shadow-lg shadow-accent/25"
              style={{
                background:
                  "linear-gradient(135deg, #fb923c 0%, #ea580c 60%, #dc2626 130%)",
              }}
            >
              {isPrep
                ? "Let's cook"
                : idx === total
                  ? "Finish 🎉"
                  : "Next step"}
              {!isPrep && idx < total && (
                <ChevronRight size={20} strokeWidth={2.6} />
              )}
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
            <h3 className="text-lg font-extrabold tracking-tight">
              Ingredients
            </h3>
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

const CONFETTI_COLORS = [
  "#fb923c",
  "#f43f5e",
  "#22c55e",
  "#3b82f6",
  "#eab308",
  "#a855f7",
];

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
