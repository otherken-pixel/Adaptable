import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import {
  ArrowBigUp,
  Bell,
  BellRing,
  Camera,
  Check,
  ChefHat,
  ChevronRight,
  Loader2,
  LogOut,
  Pencil,
  SlidersHorizontal,
  Sparkles,
  Trash2,
  X,
} from "lucide-react";
import { fetchFeed, uploadAvatar } from "@/lib/api";
import { enablePush, type PushStatus } from "@/lib/push";
import type { Recipe } from "@/lib/types";
import RecipeCard from "@/components/RecipeCard";
import { useAuth } from "@/context/AuthContext";
import { coverGradient } from "@/lib/gradients";
import { compactCount } from "@/lib/format";

export default function ProfilePage() {
  const { profile, signOut, isDemo, updateUsername, deleteAccount, setAvatarUrl } =
    useAuth();
  const avatarInputRef = useRef<HTMLInputElement>(null);
  const [avatarBusy, setAvatarBusy] = useState(false);

  const onAvatarPicked = async (file: File | null) => {
    if (!file || !profile || isDemo || avatarBusy) return;
    setAvatarBusy(true);
    try {
      const url = await uploadAvatar(profile.id, file);
      setAvatarUrl(url);
    } catch {
      /* upload failed — avatar unchanged */
    } finally {
      setAvatarBusy(false);
    }
  };
  const [mine, setMine] = useState<Recipe[]>([]);
  const [pushState, setPushState] = useState<PushStatus | "idle" | "working">("idle");

  // Username editing
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState("");
  const [savingName, setSavingName] = useState(false);
  const [nameError, setNameError] = useState<string | null>(null);

  // Account deletion
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  const onEnablePush = async () => {
    if (!profile || pushState === "working") return;
    setPushState("working");
    setPushState(await enablePush(profile.id));
  };

  const saveUsername = async () => {
    if (savingName) return;
    setSavingName(true);
    setNameError(null);
    try {
      await updateUsername(draft);
      setEditing(false);
    } catch (err) {
      setNameError(err instanceof Error ? err.message : "Could not update.");
    } finally {
      setSavingName(false);
    }
  };

  const onDeleteAccount = async () => {
    if (deleting) return;
    setDeleting(true);
    setDeleteError(null);
    try {
      await deleteAccount();
      // signOut inside deleteAccount clears the session; Shell shows AuthPage.
    } catch (err) {
      setDeleteError(err instanceof Error ? err.message : "Deletion failed.");
      setDeleting(false);
    }
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
        <div className="relative shrink-0">
          {profile.avatar_url ? (
            <img
              src={profile.avatar_url}
              alt=""
              className="h-16 w-16 rounded-full object-cover"
            />
          ) : (
            <span
              className="flex h-16 w-16 items-center justify-center rounded-full text-2xl font-extrabold text-white"
              style={{ background: coverGradient(profile.username) }}
            >
              {profile.username.slice(0, 1).toUpperCase()}
            </span>
          )}
          {!isDemo && (
            <>
              <input
                ref={avatarInputRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={(e) => void onAvatarPicked(e.target.files?.[0] ?? null)}
              />
              <button
                aria-label="Change avatar"
                onClick={() => avatarInputRef.current?.click()}
                disabled={avatarBusy}
                className="pressable absolute -right-1 -bottom-1 flex h-7 w-7 items-center justify-center rounded-full border-2 border-raised bg-content text-surface"
              >
                {avatarBusy ? (
                  <Loader2 size={12} className="animate-spin" />
                ) : (
                  <Camera size={12} strokeWidth={2.4} />
                )}
              </button>
            </>
          )}
        </div>
        <div className="min-w-0 flex-1">
          {editing ? (
            <div>
              <div className="flex items-center gap-2">
                <input
                  autoFocus
                  value={draft}
                  onChange={(e) => setDraft(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && void saveUsername()}
                  minLength={3}
                  maxLength={24}
                  className="h-10 min-w-0 flex-1 rounded-xl border border-line bg-sunken px-3 text-[15px] font-bold outline-none focus:border-accent"
                />
                <button
                  aria-label="Save username"
                  onClick={() => void saveUsername()}
                  disabled={savingName}
                  className="pressable flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-accent text-white disabled:opacity-50"
                >
                  {savingName ? (
                    <Loader2 size={15} className="animate-spin" />
                  ) : (
                    <Check size={16} strokeWidth={2.8} />
                  )}
                </button>
                <button
                  aria-label="Cancel"
                  onClick={() => {
                    setEditing(false);
                    setNameError(null);
                  }}
                  className="pressable flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-sunken text-muted"
                >
                  <X size={15} strokeWidth={2.6} />
                </button>
              </div>
              {nameError && (
                <p className="mt-1.5 text-xs font-semibold text-down">{nameError}</p>
              )}
            </div>
          ) : (
            <div className="flex items-center gap-2">
              <h2 className="truncate text-lg font-extrabold">@{profile.username}</h2>
              <button
                aria-label="Edit username"
                onClick={() => {
                  setDraft(profile.username);
                  setEditing(true);
                }}
                className="pressable flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-sunken text-muted"
              >
                <Pencil size={13} strokeWidth={2.4} />
              </button>
            </div>
          )}
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

      {/* Taste profile */}
      <Link
        to="/taste"
        className="animate-fade-up mt-4 flex items-center gap-3 rounded-card border border-line bg-raised p-5"
      >
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-2xl bg-accent-soft text-accent">
          <SlidersHorizontal size={19} strokeWidth={2.2} />
        </span>
        <div className="min-w-0 flex-1">
          <h3 className="text-[15px] font-extrabold">Taste Profile</h3>
          <p className="mt-0.5 truncate text-[13px] text-muted">
            {summarizePrefs(profile.preferences)}
          </p>
        </div>
        <ChevronRight size={18} className="shrink-0 text-faint" />
      </Link>

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
        <>
          <button
            onClick={() => void signOut()}
            className="pressable mt-8 flex w-full items-center justify-center gap-2 rounded-2xl border border-line bg-raised py-3.5 text-[15px] font-bold"
          >
            <LogOut size={17} strokeWidth={2.2} />
            Sign out
          </button>

          {/* Danger zone */}
          <div className="mt-6 rounded-card border border-down/25 p-4">
            {!confirmDelete ? (
              <button
                onClick={() => setConfirmDelete(true)}
                className="pressable flex w-full items-center justify-center gap-2 text-[14px] font-bold text-down"
              >
                <Trash2 size={15} strokeWidth={2.2} />
                Delete account
              </button>
            ) : (
              <div className="text-center">
                <p className="text-sm leading-relaxed font-semibold">
                  Permanently delete your account?
                </p>
                <p className="mt-1 text-[13px] leading-relaxed text-muted">
                  Your recipes, votes, saves, comments and groceries will be
                  erased. This cannot be undone.
                </p>
                {deleteError && (
                  <p className="mt-2 text-[13px] font-semibold text-down">
                    {deleteError}
                  </p>
                )}
                <div className="mt-3 flex gap-2">
                  <button
                    onClick={() => setConfirmDelete(false)}
                    disabled={deleting}
                    className="pressable h-11 flex-1 rounded-2xl border border-line bg-raised text-[14px] font-bold"
                  >
                    Keep my account
                  </button>
                  <button
                    onClick={() => void onDeleteAccount()}
                    disabled={deleting}
                    className="pressable flex h-11 flex-1 items-center justify-center gap-2 rounded-2xl bg-down text-[14px] font-bold text-white disabled:opacity-60"
                  >
                    {deleting && <Loader2 size={15} className="animate-spin" />}
                    Delete forever
                  </button>
                </div>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}

function summarizePrefs(prefs?: {
  diets?: string[];
  allergies?: string[];
  household_size?: number;
}): string {
  const bits: string[] = [];
  if (prefs?.diets?.length) bits.push(prefs.diets.join(", "));
  if (prefs?.allergies?.length) bits.push(`no ${prefs.allergies.join(", ")}`);
  if (prefs?.household_size) bits.push(`cooks for ${prefs.household_size}`);
  return bits.length > 0
    ? bits.join(" · ")
    : "Diets, allergies, dislikes — the AI cooks around you";
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
