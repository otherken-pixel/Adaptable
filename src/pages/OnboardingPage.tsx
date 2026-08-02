import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { ArrowRight, Check, Shield } from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import type { Preferences } from "@/lib/types";
import { formatList } from "@/lib/locale";

const DIETS = [
  "Vegetarian",
  "Vegan",
  "Pescatarian",
  "Keto",
  "Paleo",
  "Gluten-free",
  "Dairy-free",
  "Halal",
  "Kosher",
];

const ALLERGIES = [
  "Peanuts",
  "Tree nuts",
  "Dairy",
  "Eggs",
  "Gluten",
  "Shellfish",
  "Fish",
  "Soy",
  "Sesame",
];

const SPICE = ["Mild", "Medium", "Hot"] as const;
const SKILL = ["Beginner", "Confident", "Pro"] as const;

const STEPS = ["Welcome", "Diets", "Allergies", "Household", "Done"] as const;

/**
 * Multi-step first-run flow so users hit “wow” with a personal profile
 * before a cold Discover feed.
 */
export default function OnboardingPage() {
  const { profile, updatePreferences } = useAuth();
  const navigate = useNavigate();
  const [step, setStep] = useState(0);
  const [busy, setBusy] = useState(false);
  const [prefs, setPrefs] = useState<Preferences>(() => ({
    diets: profile?.preferences?.diets ?? [],
    allergies: profile?.preferences?.allergies ?? [],
    dislikes: profile?.preferences?.dislikes ?? [],
    household_size: profile?.preferences?.household_size ?? 2,
    spice: profile?.preferences?.spice ?? "Medium",
    skill: profile?.preferences?.skill ?? "Confident",
  }));

  const progress = ((step + 1) / STEPS.length) * 100;

  const summary = useMemo(() => {
    const bits: string[] = [];
    if (prefs.diets?.length) bits.push(formatList(prefs.diets));
    if (prefs.allergies?.length)
      bits.push(`no ${formatList(prefs.allergies)}`);
    if (prefs.household_size)
      bits.push(`cooks for ${prefs.household_size}`);
    return bits.join(" · ") || "Flexible eater";
  }, [prefs]);

  const toggle = (key: "diets" | "allergies", value: string) => {
    setPrefs((p) => {
      const list = new Set(p[key] ?? []);
      if (list.has(value)) list.delete(value);
      else list.add(value);
      return { ...p, [key]: [...list] };
    });
  };

  const finish = async (save: boolean) => {
    setBusy(true);
    try {
      if (save) await updatePreferences(prefs);
      localStorage.setItem("adaptable.onboarding.v1.done", "1");
      localStorage.setItem("adaptable.tasteNudge.v1.dismissed", "1");
      navigate("/create", { replace: true });
    } catch {
      setBusy(false);
    }
  };

  const next = () => {
    if (step < STEPS.length - 1) setStep((s) => s + 1);
    else void finish(true);
  };

  return (
    <div className="mx-auto flex min-h-dvh max-w-lg flex-col px-4 pt-safe pb-safe">
      <div className="pt-6">
        <div
          className="h-1.5 overflow-hidden rounded-full bg-sunken"
          role="progressbar"
          aria-valuenow={step + 1}
          aria-valuemin={1}
          aria-valuemax={STEPS.length}
          aria-label="Onboarding progress"
        >
          <div
            className="h-full rounded-full bg-accent transition-all duration-300"
            style={{ width: `${progress}%` }}
          />
        </div>
        <p className="mt-2 text-xs font-bold tracking-wide text-faint uppercase">
          Step {step + 1} of {STEPS.length}
        </p>
      </div>

      <div className="flex flex-1 flex-col justify-center py-8">
        {step === 0 && (
          <div className="space-y-4 animate-fade-up">
            <p className="text-5xl" aria-hidden>
              🍳
            </p>
            <h1 className="text-[28px] font-extrabold tracking-tight">
              Welcome{profile?.username ? `, ${profile.username}` : ""}
            </h1>
            <p className="text-[15px] leading-relaxed text-muted">
              In under a minute we&apos;ll learn how you eat — especially
              allergies, which we treat as a hard safety rule on every AI
              recipe.
            </p>
            <div className="flex items-start gap-3 rounded-2xl border border-accent/25 bg-accent-soft p-4">
              <Shield size={18} className="mt-0.5 shrink-0 text-accent" />
              <p className="text-[13px] font-semibold leading-snug text-accent">
                Always double-check ingredients for severe allergies. We block
                obvious mismatches, but you&apos;re the final safety check.
              </p>
            </div>
          </div>
        )}

        {step === 1 && (
          <div className="space-y-4 animate-fade-up">
            <h1 className="text-[26px] font-extrabold tracking-tight">
              Any diets?
            </h1>
            <p className="text-[15px] text-muted">
              Pick all that apply — or skip if you&apos;re flexible.
            </p>
            <div className="flex flex-wrap gap-2">
              {DIETS.map((d) => {
                const on = prefs.diets?.includes(d);
                return (
                  <button
                    key={d}
                    type="button"
                    aria-pressed={!!on}
                    onClick={() => toggle("diets", d)}
                    className={`pressable rounded-full px-4 py-2 text-[13px] font-bold ${
                      on
                        ? "bg-content text-surface"
                        : "border border-line bg-raised text-muted"
                    }`}
                  >
                    {d}
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {step === 2 && (
          <div className="space-y-4 animate-fade-up">
            <h1 className="text-[26px] font-extrabold tracking-tight">
              Allergies & hard avoids
            </h1>
            <p className="text-[15px] text-muted">
              We never want these in a generated or imported recipe.
            </p>
            <div className="flex flex-wrap gap-2">
              {ALLERGIES.map((a) => {
                const on = prefs.allergies?.includes(a);
                return (
                  <button
                    key={a}
                    type="button"
                    aria-pressed={!!on}
                    onClick={() => toggle("allergies", a)}
                    className={`pressable rounded-full px-4 py-2 text-[13px] font-bold ${
                      on
                        ? "bg-down/15 text-down ring-1 ring-down/40"
                        : "border border-line bg-raised text-muted"
                    }`}
                  >
                    {a}
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {step === 3 && (
          <div className="space-y-5 animate-fade-up">
            <h1 className="text-[26px] font-extrabold tracking-tight">
              Household & vibe
            </h1>
            <div>
              <p className="mb-2 text-xs font-bold tracking-wide text-faint uppercase">
                People you cook for
              </p>
              <div className="flex items-center gap-3">
                <button
                  type="button"
                  aria-label="Fewer people"
                  className="pressable flex h-11 w-11 items-center justify-center rounded-full border border-line bg-raised text-lg font-bold"
                  onClick={() =>
                    setPrefs((p) => ({
                      ...p,
                      household_size: Math.max(1, (p.household_size ?? 2) - 1),
                    }))
                  }
                >
                  −
                </button>
                <span className="min-w-10 text-center text-2xl font-extrabold tabular-nums">
                  {prefs.household_size ?? 2}
                </span>
                <button
                  type="button"
                  aria-label="More people"
                  className="pressable flex h-11 w-11 items-center justify-center rounded-full border border-line bg-raised text-lg font-bold"
                  onClick={() =>
                    setPrefs((p) => ({
                      ...p,
                      household_size: Math.min(12, (p.household_size ?? 2) + 1),
                    }))
                  }
                >
                  +
                </button>
              </div>
            </div>
            <div>
              <p className="mb-2 text-xs font-bold tracking-wide text-faint uppercase">
                Spice
              </p>
              <div className="flex flex-wrap gap-2">
                {SPICE.map((s) => (
                  <button
                    key={s}
                    type="button"
                    aria-pressed={prefs.spice === s}
                    onClick={() => setPrefs((p) => ({ ...p, spice: s }))}
                    className={`pressable rounded-full px-4 py-2 text-[13px] font-bold ${
                      prefs.spice === s
                        ? "bg-content text-surface"
                        : "border border-line bg-raised text-muted"
                    }`}
                  >
                    {s}
                  </button>
                ))}
              </div>
            </div>
            <div>
              <p className="mb-2 text-xs font-bold tracking-wide text-faint uppercase">
                Skill
              </p>
              <div className="flex flex-wrap gap-2">
                {SKILL.map((s) => (
                  <button
                    key={s}
                    type="button"
                    aria-pressed={prefs.skill === s}
                    onClick={() => setPrefs((p) => ({ ...p, skill: s }))}
                    className={`pressable rounded-full px-4 py-2 text-[13px] font-bold ${
                      prefs.skill === s
                        ? "bg-content text-surface"
                        : "border border-line bg-raised text-muted"
                    }`}
                  >
                    {s}
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}

        {step === 4 && (
          <div className="space-y-4 animate-fade-up">
            <p className="text-5xl" aria-hidden>
              ✨
            </p>
            <h1 className="text-[26px] font-extrabold tracking-tight">
              You&apos;re set
            </h1>
            <p className="text-[15px] leading-relaxed text-muted">
              We&apos;ll adapt every AI recipe to:{" "}
              <span className="font-bold text-content">{summary}</span>
            </p>
            <p className="flex items-center gap-2 text-[13px] font-semibold text-accent">
              <Check size={16} strokeWidth={2.6} /> Ready to generate your first
              dinner
            </p>
          </div>
        )}
      </div>

      <div className="space-y-3 pb-6">
        <button
          type="button"
          disabled={busy}
          onClick={next}
          className="pressable flex h-14 w-full items-center justify-center gap-2 rounded-2xl text-[16px] font-extrabold text-white shadow-lg shadow-accent/25 disabled:opacity-60"
          style={{
            background:
              "linear-gradient(135deg, #fb923c 0%, #ea580c 60%, #dc2626 130%)",
          }}
        >
          {step === STEPS.length - 1 ? "Generate a recipe" : "Continue"}
          <ArrowRight size={18} strokeWidth={2.4} aria-hidden />
        </button>
        {step > 0 && step < STEPS.length - 1 && (
          <button
            type="button"
            onClick={() => setStep((s) => s + 1)}
            className="pressable w-full py-2 text-center text-sm font-bold text-muted"
          >
            Skip for now
          </button>
        )}
        {step === 0 && (
          <button
            type="button"
            onClick={() => void finish(false)}
            className="pressable w-full py-2 text-center text-sm font-bold text-muted"
          >
            Skip onboarding
          </button>
        )}
      </div>
    </div>
  );
}
