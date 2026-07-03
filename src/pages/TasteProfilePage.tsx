import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Check, ChevronLeft, Loader2, Minus, Plus, ShieldAlert, X } from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import type { Preferences } from "@/lib/types";

const DIETS = [
  "Vegetarian", "Vegan", "Pescatarian", "Keto", "Paleo",
  "Gluten-free", "Dairy-free", "Halal", "Kosher", "Low-carb",
];

const ALLERGIES = [
  "Peanuts", "Tree nuts", "Shellfish", "Fish", "Eggs",
  "Dairy", "Gluten", "Soy", "Sesame",
];

const SPICE = ["Mild", "Medium", "Hot"] as const;
const SKILL = ["Beginner", "Confident", "Pro"] as const;

/**
 * Taste profile editor. Everything here is injected into every AI
 * generation — allergies as a hard safety rule.
 */
export default function TasteProfilePage() {
  const { profile, updatePreferences } = useAuth();
  const navigate = useNavigate();
  const initial = profile?.preferences ?? {};

  const [diets, setDiets] = useState<string[]>(initial.diets ?? []);
  const [allergies, setAllergies] = useState<string[]>(initial.allergies ?? []);
  const [dislikes, setDislikes] = useState<string[]>(initial.dislikes ?? []);
  const [dislikeDraft, setDislikeDraft] = useState("");
  const [household, setHousehold] = useState(initial.household_size ?? 4);
  const [spice, setSpice] = useState<Preferences["spice"]>(initial.spice);
  const [skill, setSkill] = useState<Preferences["skill"]>(initial.skill);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  const toggle = (list: string[], set: (v: string[]) => void, item: string) =>
    set(list.includes(item) ? list.filter((i) => i !== item) : [...list, item]);

  const addDislike = () => {
    const item = dislikeDraft.trim();
    if (!item) return;
    if (!dislikes.some((d) => d.toLowerCase() === item.toLowerCase())) {
      setDislikes([...dislikes, item]);
    }
    setDislikeDraft("");
  };

  const save = async () => {
    if (saving) return;
    setSaving(true);
    try {
      await updatePreferences({
        diets,
        allergies,
        dislikes,
        household_size: household,
        spice,
        skill,
      });
      setSaved(true);
      setTimeout(() => navigate(-1), 900);
    } catch {
      setSaving(false);
    }
  };

  return (
    <div className="mx-auto max-w-lg px-4 pt-safe pb-nav">
      <div className="flex items-center pt-4 pb-2">
        <button
          aria-label="Back"
          onClick={() => navigate(-1)}
          className="pressable -ml-2 flex h-10 w-10 items-center justify-center rounded-full text-muted"
        >
          <ChevronLeft size={26} strokeWidth={2.4} />
        </button>
      </div>

      <header className="pb-5">
        <p className="text-xs font-bold tracking-[0.18em] text-accent uppercase">
          Personalization
        </p>
        <h1 className="mt-1 text-[32px] leading-none font-extrabold tracking-tight">
          Taste Profile
        </h1>
        <p className="mt-2 text-sm leading-relaxed text-muted">
          Every recipe the AI creates for you respects this — automatically.
        </p>
      </header>

      <Section title="Diets">
        <ChipGrid items={DIETS} selected={diets} onToggle={(i) => toggle(diets, setDiets, i)} />
      </Section>

      <Section
        title="Allergies"
        badge={
          <span className="flex items-center gap-1 rounded-full bg-down/10 px-2.5 py-1 text-[11px] font-bold text-down">
            <ShieldAlert size={11} strokeWidth={2.6} /> Always excluded
          </span>
        }
      >
        <ChipGrid
          items={ALLERGIES}
          selected={allergies}
          onToggle={(i) => toggle(allergies, setAllergies, i)}
          danger
        />
      </Section>

      <Section title="Ingredients you dislike">
        {dislikes.length > 0 && (
          <div className="mb-3 flex flex-wrap gap-2">
            {dislikes.map((d) => (
              <button
                key={d}
                onClick={() => setDislikes(dislikes.filter((i) => i !== d))}
                className="pressable flex items-center gap-1.5 rounded-full bg-accent-soft px-3.5 py-2 text-[13px] font-bold text-accent"
              >
                {d}
                <X size={13} strokeWidth={2.8} />
              </button>
            ))}
          </div>
        )}
        <div className="flex items-center gap-2 rounded-2xl border border-line bg-raised p-1.5 pl-4">
          <input
            value={dislikeDraft}
            onChange={(e) => setDislikeDraft(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                e.preventDefault();
                addDislike();
              }
            }}
            maxLength={40}
            placeholder="e.g. cilantro, olives, blue cheese…"
            className="h-10 min-w-0 flex-1 bg-transparent text-[15px] outline-none placeholder:text-faint"
          />
          <button
            aria-label="Add dislike"
            onClick={addDislike}
            disabled={!dislikeDraft.trim()}
            className="pressable flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-sunken text-muted disabled:opacity-30"
          >
            <Plus size={17} strokeWidth={2.6} />
          </button>
        </div>
      </Section>

      <Section title="Household size">
        <div className="flex items-center justify-between rounded-2xl border border-line bg-raised px-4 py-2.5">
          <span className="text-[14px] font-bold">Usually cooking for</span>
          <div className="flex items-center gap-1 rounded-full bg-sunken p-1">
            <button
              aria-label="Fewer people"
              onClick={() => setHousehold((h) => Math.max(1, h - 1))}
              className="pressable flex h-8 w-8 items-center justify-center rounded-full bg-raised text-muted shadow-sm"
            >
              <Minus size={15} strokeWidth={2.6} />
            </button>
            <span className="min-w-16 text-center text-[13px] font-extrabold">
              {household} {household === 1 ? "person" : "people"}
            </span>
            <button
              aria-label="More people"
              onClick={() => setHousehold((h) => Math.min(12, h + 1))}
              className="pressable flex h-8 w-8 items-center justify-center rounded-full bg-raised text-muted shadow-sm"
            >
              <Plus size={15} strokeWidth={2.6} />
            </button>
          </div>
        </div>
      </Section>

      <Section title="Spice tolerance">
        <Segmented options={SPICE} value={spice} onChange={setSpice} />
      </Section>

      <Section title="Cooking skill">
        <Segmented options={SKILL} value={skill} onChange={setSkill} />
      </Section>

      <button
        onClick={() => void save()}
        disabled={saving}
        className="pressable mt-2 mb-4 flex h-14 w-full items-center justify-center gap-2 rounded-2xl text-[16px] font-extrabold text-white shadow-lg shadow-accent/25 disabled:opacity-60"
        style={{
          background:
            "linear-gradient(135deg, #fb923c 0%, #ea580c 60%, #dc2626 130%)",
        }}
      >
        {saved ? (
          <>
            <Check size={19} strokeWidth={2.6} className="animate-pop" /> Saved
          </>
        ) : saving ? (
          <Loader2 size={18} className="animate-spin" />
        ) : (
          "Save taste profile"
        )}
      </button>
    </div>
  );
}

function Section({
  title,
  badge,
  children,
}: {
  title: string;
  badge?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <section className="mb-6">
      <div className="mb-2.5 flex items-center gap-2">
        <h2 className="text-[15px] font-extrabold tracking-tight">{title}</h2>
        {badge}
      </div>
      {children}
    </section>
  );
}

function ChipGrid({
  items,
  selected,
  onToggle,
  danger = false,
}: {
  items: string[];
  selected: string[];
  onToggle: (item: string) => void;
  danger?: boolean;
}) {
  return (
    <div className="flex flex-wrap gap-2">
      {items.map((item) => {
        const active = selected.includes(item);
        return (
          <button
            key={item}
            onClick={() => onToggle(item)}
            className={`pressable rounded-full px-3.5 py-2 text-[13px] font-bold transition-colors ${
              active
                ? danger
                  ? "bg-down text-white"
                  : "bg-content text-surface"
                : "border border-line bg-raised text-muted"
            }`}
          >
            {item}
          </button>
        );
      })}
    </div>
  );
}

function Segmented<T extends string>({
  options,
  value,
  onChange,
}: {
  options: readonly T[];
  value: T | undefined;
  onChange: (v: T | undefined) => void;
}) {
  return (
    <div className="flex rounded-2xl bg-sunken p-1">
      {options.map((opt) => (
        <button
          key={opt}
          onClick={() => onChange(value === opt ? undefined : opt)}
          className={`pressable flex-1 rounded-xl py-2.5 text-[13px] font-bold transition-colors ${
            value === opt ? "bg-raised text-content shadow-sm" : "text-muted"
          }`}
        >
          {opt}
        </button>
      ))}
    </div>
  );
}
