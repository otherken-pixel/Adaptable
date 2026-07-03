import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { KeyRound, Loader2 } from "lucide-react";
import { useAuth } from "@/context/AuthContext";

/**
 * Landing page for Supabase password-recovery links. The recovery link
 * signs the user in with a temporary session; this screen sets the new
 * password via auth.updateUser.
 */
export default function ResetPasswordPage() {
  const { updatePassword } = useAuth();
  const navigate = useNavigate();
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    if (password !== confirm) {
      setError("Passwords don't match.");
      return;
    }
    setBusy(true);
    try {
      await updatePassword(password);
      setDone(true);
      setTimeout(() => navigate("/", { replace: true }), 1500);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not update password.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="mx-auto flex min-h-dvh max-w-lg flex-col justify-center px-6 pt-safe pb-safe">
      <div className="animate-fade-up flex flex-col items-center pb-8 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-3xl bg-accent-soft text-accent">
          <KeyRound size={30} strokeWidth={2} />
        </div>
        <h1 className="mt-5 text-2xl font-extrabold tracking-tight">
          Set a new password
        </h1>
        <p className="mt-2 max-w-64 text-sm leading-relaxed text-muted">
          You're signed in via your recovery link — choose a new password to
          finish.
        </p>
      </div>

      {done ? (
        <p className="animate-fade-up rounded-xl bg-accent-soft px-4 py-3 text-center text-sm font-bold text-accent">
          Password updated 🎉 Taking you home…
        </p>
      ) : (
        <form onSubmit={submit} className="animate-fade-up space-y-3">
          <label className="block">
            <span className="mb-1.5 block text-xs font-bold tracking-wide text-muted uppercase">
              New password
            </span>
            <input
              type="password"
              required
              minLength={6}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              className="h-13 w-full rounded-2xl border border-line bg-raised px-4 text-[15px] outline-none placeholder:text-faint focus:border-accent"
            />
          </label>
          <label className="block">
            <span className="mb-1.5 block text-xs font-bold tracking-wide text-muted uppercase">
              Confirm password
            </span>
            <input
              type="password"
              required
              minLength={6}
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              placeholder="••••••••"
              className="h-13 w-full rounded-2xl border border-line bg-raised px-4 text-[15px] outline-none placeholder:text-faint focus:border-accent"
            />
          </label>

          {error && (
            <p className="rounded-xl bg-down/10 px-4 py-2.5 text-[13px] font-semibold text-down">
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={busy}
            className="pressable flex h-13 w-full items-center justify-center gap-2 rounded-2xl bg-content text-[15px] font-bold text-surface shadow-lg disabled:opacity-50"
          >
            {busy && <Loader2 size={17} className="animate-spin" />}
            Update password
          </button>
        </form>
      )}
    </div>
  );
}
