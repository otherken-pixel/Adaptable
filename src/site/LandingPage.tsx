import { useEffect } from "react";
import { useLocation } from "react-router-dom";
import {
  Camera,
  ChefHat,
  Clock,
  Gauge,
  ShieldCheck,
  ShoppingCart,
  Sparkles,
  Timer,
} from "lucide-react";
import RecipeCover from "@/components/RecipeCover";
import MarketingLayout from "./MarketingLayout";
import BrandMark from "./BrandMark";
import AppStoreCta from "./AppStoreCta";

const FEATURES = [
  {
    icon: Sparkles,
    title: "Describe dinner",
    body: "Time, diet, whatever’s in the fridge. Get a structured recipe in seconds.",
  },
  {
    icon: Camera,
    title: "Import anything",
    body: "Paste a link, snap a cookbook page, or share from Safari. We extract a clean recipe.",
  },
  {
    icon: ShieldCheck,
    title: "Taste and allergies",
    body: "Diets, dislikes, and allergens ride along with every generation. Always read the label anyway.",
  },
  {
    icon: Timer,
    title: "Cook Mode",
    body: "One step at a time, huge type, Live Activities on the Lock Screen, optional voice commands.",
  },
  {
    icon: ShoppingCart,
    title: "Groceries",
    body: "Scale servings and send the week to a list — or out to Apple Reminders.",
  },
  {
    icon: ChefHat,
    title: "Built for iPhone",
    body: "Widgets, share sheet, and timers that keep going when you pocket the phone.",
  },
] as const;

const STEPS = [
  { n: "1", title: "Tell us the constraint", body: "A craving, a photo, a link, or a fridge." },
  { n: "2", title: "Get a recipe that fits", body: "Ingredients, steps, macros, scaled to your household." },
  { n: "3", title: "Cook on your phone", body: "Timers, a grocery list, and a save to your Cookbook." },
] as const;

const FAQ = [
  {
    q: "Is there a web app?",
    a: "No. Adaptable is an iPhone app. This site is for download, support, and legal pages.",
  },
  {
    q: "Does it know my allergies?",
    a: "Set them in Taste Profile. We try to block listed allergens when we can detect them. That is not a guarantee — always check ingredients yourself.",
  },
  {
    q: "How do I delete my account?",
    a: "In the iPhone app: Profile → Delete account. Or email support@adaptable.app.",
  },
] as const;

export default function LandingPage() {
  const { hash } = useLocation();
  useEffect(() => {
    if (!hash) return;
    document.querySelector(hash)?.scrollIntoView({ behavior: "smooth" });
  }, [hash]);

  return (
    <MarketingLayout>
      <section className="mx-auto grid max-w-6xl items-center gap-12 px-5 pt-14 pb-16 sm:pt-20 lg:grid-cols-2">
        <div>
          <div className="mb-6">
            <BrandMark size={56} />
          </div>
          <p className="text-[11px] font-extrabold tracking-[0.14em] text-accent uppercase">
            For iPhone
          </p>
          <h1 className="mt-3 text-4xl font-extrabold tracking-tight sm:text-6xl sm:leading-[1.05]">
            AI recipes that adapt to you.
          </h1>
          <p className="mt-4 max-w-lg text-lg leading-relaxed text-muted">
            Diets, allergies, time, and whatever is already in the fridge.
            Generate, import, and cook — in an app built for the kitchen.
          </p>
          <div className="mt-8">
            <AppStoreCta size="lg" />
          </div>
        </div>
        <PhonePreview />
      </section>

      <section id="features" className="scroll-mt-16 border-t border-line">
        <div className="mx-auto grid max-w-6xl gap-4 px-5 py-14 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((f) => (
            <div
              key={f.title}
              className="rounded-card border border-line bg-raised p-5"
            >
              <span className="flex h-10 w-10 items-center justify-center rounded-2xl bg-accent-soft text-accent">
                <f.icon size={18} strokeWidth={2.2} />
              </span>
              <h2 className="mt-3 text-[16px] font-extrabold">{f.title}</h2>
              <p className="mt-1 text-sm leading-relaxed text-muted">{f.body}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="border-t border-line">
        <div className="mx-auto max-w-6xl px-5 py-14">
          <h2 className="text-2xl font-extrabold tracking-tight">How it works</h2>
          <div className="mt-8 grid gap-6 sm:grid-cols-3">
            {STEPS.map((s) => (
              <div key={s.n}>
                <span className="text-sm font-extrabold text-accent">{s.n}</span>
                <h3 className="mt-1 text-[16px] font-extrabold">{s.title}</h3>
                <p className="mt-1 text-sm leading-relaxed text-muted">{s.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="border-t border-line">
        <div className="mx-auto max-w-6xl px-5 py-14">
          <div className="rounded-card border border-line bg-raised p-6 sm:p-8">
            <div className="flex items-start gap-3">
              <ChefHat className="mt-0.5 shrink-0 text-accent" size={22} strokeWidth={2.2} />
              <div>
                <h2 className="text-lg font-extrabold">Cook carefully</h2>
                <p className="mt-2 text-[15px] leading-relaxed text-muted">
                  Allergen blocking is best-effort, not a medical device. AI
                  recipes can be wrong. Read the ingredients, use a food
                  thermometer, and ignore any step that looks unsafe.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="border-t border-line">
        <div className="mx-auto max-w-3xl px-5 py-14">
          <h2 className="text-2xl font-extrabold tracking-tight">FAQ</h2>
          <dl className="mt-6 space-y-6">
            {FAQ.map((item) => (
              <div key={item.q}>
                <dt className="font-extrabold">{item.q}</dt>
                <dd className="mt-1 text-[15px] leading-relaxed text-muted">
                  {item.a}
                </dd>
              </div>
            ))}
          </dl>
        </div>
      </section>
    </MarketingLayout>
  );
}

function PhonePreview() {
  return (
    <div className="mx-auto w-full max-w-[320px]" aria-hidden>
      <div className="rounded-[2.4rem] border border-line bg-content p-3 shadow-2xl shadow-accent/10">
        <div className="overflow-hidden rounded-[1.9rem] bg-surface">
          <div className="px-5 pt-8 pb-4">
            <p className="text-[11px] font-extrabold tracking-[0.14em] text-accent uppercase">
              For you
            </p>
            <p className="mt-1 text-2xl font-extrabold tracking-tight">Tonight</p>
          </div>
          <div className="mx-4 mb-5 overflow-hidden rounded-card border border-line bg-raised shadow-[0_2px_16px_rgb(0_0_0/0.05)]">
            <RecipeCover
              recipeId="marketing-hero"
              imageUrl="/marketing/hero-pasta.jpg"
              cuisine="Italian"
              heightClass="h-40"
            />
            <div className="space-y-3 p-4">
              <div>
                <h3 className="text-[17px] leading-snug font-bold tracking-tight">
                  20-minute spicy tomato pasta
                </h3>
                <p className="mt-1 line-clamp-2 text-sm leading-relaxed text-muted">
                  Pantry staples. High protein. Your heat level.
                </p>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <span className="flex items-center gap-1 rounded-full bg-sunken px-2.5 py-1 text-xs font-semibold text-muted">
                  <Clock size={13} strokeWidth={2.2} />
                  20 min
                </span>
                <span className="flex items-center gap-1 rounded-full bg-sunken px-2.5 py-1 text-xs font-semibold text-muted">
                  <Gauge size={13} strokeWidth={2.2} />
                  Easy
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
