import { useEffect, useState } from "react";
import { ArrowBigUp, Bell, BellRing, ChefHat, LogOut, Sparkles } from "lucide-react";
import { fetchFeed } from "@/lib/api";
import { enablePush, type PushStatus } from "@/lib/push";
import type { Recipe } from "@/lib/types";
import RecipeCard from "@/components/RecipeCard";
import { useAuth } from "@/context/AuthContext";
import { coverGradient } from "@/lib/gradients";
import { compactCount } from "@/lib/format";

export default function ProfilePage() {
  const { profile, signOut, isDemo } = useAuth();
  const [mine, setMine] = useState<Recipe[]>([]);
  const [pushState, setPushState] = useState<PushStatus | "idle" | "working">("idle");

  const onEnablePush = async () => {
    if (!profile || pushState === "working") return;
    setPushState("working");
    setPushState(await enablePush(profile.id));
  };

  useEffect(() => {
    if (!profile) return;
    let cancelled = false;
    fetchFeed("new")
      .then((all) => {
        if (!cancelled) setMine(all.filter((r) => r.author_id === profile.id));
      })
      .catch(() => {
        /* stats stay at zero */
      });
    return () => {
      cancelled = true;
    };
  }, [profile]);

  if (!profile) return null;

  const totalUpvotes = mine.reduce((sum, r) => sum + Math.max(0, r.net_upvotes), 0);

  return (
    <div className="mx-auto max-w-lg px-4 pt-safe pb-nav">
      <header className="pt-6 pb-4">
        <p className="text-xs font-bold tracking-[0.18em] text-accent uppercase">
          Profile
        </p>
        <h1 className="mt-1 text-[32px] leading-none font-extrabold tracking-tight">
          You
        </h1>
      </header>

      <div className="animate-fade-up flex items-center gap-4 rounded-card border border-line bg-raised p-5">
        <span
          className="flex h-16 w-16 shrink-0 items-center justify-center rounded-full text-2xl font-extrabold text-white"
          style={{ background: coverGradient(profile.username) }}
        >
          {profile.username.slice(0, 1).toUpperCase()}
        </span>
        <div className="min-w-0">
          <h2 className="truncate text-lg font-extrabold">@{profile.username}</h2>
          <p className="text-sm text-muted">
            {isDemo ? "Demo chef — data stays on this device" : "Adaptable chef"}
          </p>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-2 gap-3">
        <StatCard
          icon={<ChefHat size={18} className="text-accent" />}
          value={String(mine.length)}
          label="Recipes created"
        />
        <StatCard
          icon={<ArrowBigUp size={18} className="text-up" />}
          value={compactCount(totalUpvotes)}
          label="Upvotes earned"
        />
      </div>

      {mine.length > 0 && (
        <section className="mt-7">
          <h2 className="mb-3 text-lg font-extrabold tracking-tight">
            Your creations
          </h2>
          <div className="space-y-4">
            {mine.map((r, i) => (
              <RecipeCard key={r.id} recipe={r} index={i} />
            ))}
          </div>
        </section>
      )}

      {mine.length === 0 && (
        <div className="animate-fade-up mt-7 flex flex-col items-center gap-2 rounded-card border border-dashed border-line px-6 py-10 text-center">
          <Sparkles size={22} className="text-accent" />
          <p className="text-sm font-semibold">No creations yet</p>
          <p className="max-w-60 text-[13px] leading-relaxed text-muted">
            Head to Create and describe your dream meal — your recipes will show
            up here.
          </p>
        </div>
      )}

      {/* Push notifications */}
      <div className="animate-fade-up mt-7 rounded-card border border-line bg-raised p-5">
        <div className="flex items-start gap-3">
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-2xl bg-accent-soft text-accent">
            {pushState === "enabled" ? (
              <BellRing size={19} strokeWidth={2.2} />
            ) : (
              <Bell size={19} strokeWidth={2.2} />
            )}
          </span>
          <div className="min-w-0 flex-1">
            <h3 className="text-[15px] font-extrabold">Push notifications</h3>
            <p className="mt-0.5 text-[13px] leading-relaxed text-muted">
              {pushState === "enabled"
                ? "You're set — Supabase pings APNs directly when your recipes get votes, comments and cooks."
                : pushState === "unsupported"
                  ? "Device push runs on the iOS app (npm run cap:ios) via Supabase → APNs, no Firebase. Everywhere else, the Activity inbox updates live over Supabase Realtime."
                  : pushState === "denied"
                    ? "Permission was declined — enable notifications for Adaptable in system settings, then try again."
                    : "Get pinged when your recipes earn votes, comments and cooks."}
            </p>
          </div>
          {pushState !== "enabled" && pushState !== "unsupported" && (
            <button
              onClick={() => void onEnablePush()}
              disabled={pushState === "working"}
              className="pressable shrink-0 rounded-full bg-content px-4 py-2 text-[13px] font-bold text-surface disabled:opacity-50"
            >
              {pushState === "working" ? "…" : "Enable"}
            </button>
          )}
        </div>
      </div>

      {!isDemo && (
        <button
          onClick={() => void signOut()}
          className="pressable mt-8 flex w-full items-center justify-center gap-2 rounded-2xl border border-line bg-raised py-3.5 text-[15px] font-bold text-down"
        >
          <LogOut size={17} strokeWidth={2.2} />
          Sign out
        </button>
      )}
    </div>
  );
}

function StatCard({
  icon,
  value,
  label,
}: {
  icon: React.ReactNode;
  value: string;
  label: string;
}) {
  return (
    <div className="animate-fade-up rounded-card border border-line bg-raised p-4">
      <div className="flex items-center gap-2">
        {icon}
        <span className="text-2xl font-extrabold tabular-nums">{value}</span>
      </div>
      <p className="mt-1 text-xs font-semibold text-muted">{label}</p>
    </div>
  );
}
