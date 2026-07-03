import { useState, type FormEvent } from "react";
import { ChefHat, Loader2 } from "lucide-react";
import { useAuth } from "@/context/AuthContext";

type Mode = "signin" | "signup" | "forgot";

export default function AuthPage() {
  const { signInWithPassword, signUp, signInWithGoogle, requestPasswordReset } =
    useAuth();
  const [mode, setMode] = useState<Mode>("signin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [username, setUsername] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      if (mode === "signin") {
        await signInWithPassword(email, password);
      } else if (mode === "signup") {
        await signUp(email, password, username);
        setNotice("Check your inbox to confirm your email, then sign in.");
      } else {
        await requestPasswordReset(email);
        setNotice("Reset link sent — check your inbox.");
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong.");
    } finally {
      setBusy(false);
    }
  };

  const google = async () => {
    setError(null);
    try {
      await signInWithGoogle();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Google sign-in failed.");
    }
  };

  return (
    <div className="mx-auto flex min-h-dvh max-w-lg flex-col justify-center px-6 pt-safe pb-safe">
      <div className="animate-fade-up flex flex-col items-center pb-8 text-center">
        <div
          className="flex h-20 w-20 animate-float items-center justify-center rounded-3xl shadow-xl shadow-accent/25"
          style={{
            background:
              "linear-gradient(135deg, #fb923c 0%, #ea580c 55%, #dc2626 120%)",
          }}
        >
          <ChefHat size={38} className="text-white" strokeWidth={2} />
        </div>
        <h1 className="mt-5 text-3xl font-extrabold tracking-tight">Adaptable</h1>
        <p className="mt-2 max-w-64 text-sm leading-relaxed text-muted">
          AI recipes that adapt to you. Generate, cook, vote.
        </p>
      </div>

      <form onSubmit={submit} className="animate-fade-up space-y-3">
        {mode === "signup" && (
          <Field
            label="Username"
            type="text"
            value={username}
            onChange={setUsername}
            placeholder="chef_you"
            minLength={3}
            maxLength={24}
          />
        )}
        <Field
          label="Email"
          type="email"
          value={email}
          onChange={setEmail}
          placeholder="you@example.com"
        />
        {mode !== "forgot" && (
          <Field
            label="Password"
            type="password"
            value={password}
            onChange={setPassword}
            placeholder="••••••••"
            minLength={6}
          />
        )}
        {mode === "signin" && (
          <button
            type="button"
            onClick={() => {
              setMode("forgot");
              setError(null);
              setNotice(null);
            }}
            className="pressable -mt-1 block text-right text-[13px] font-semibold text-muted"
            style={{ marginLeft: "auto" }}
          >
            Forgot password?
          </button>
        )}

        {error && (
          <p className="rounded-xl bg-down/10 px-4 py-2.5 text-[13px] font-semibold text-down">
            {error}
          </p>
        )}
        {notice && (
          <p className="rounded-xl bg-accent-soft px-4 py-2.5 text-[13px] font-semibold text-accent">
            {notice}
          </p>
        )}

        <button
          type="submit"
          disabled={busy}
          className="pressable flex h-13 w-full items-center justify-center gap-2 rounded-2xl bg-content text-[15px] font-bold text-surface shadow-lg disabled:opacity-50"
        >
          {busy && <Loader2 size={17} className="animate-spin" />}
          {mode === "signin"
            ? "Sign in"
            : mode === "signup"
              ? "Create account"
              : "Send reset link"}
        </button>
      </form>

      {mode !== "forgot" && (
        <>
          <div className="my-5 flex items-center gap-3">
            <span className="h-px flex-1 bg-line" />
            <span className="text-xs font-semibold text-faint">or</span>
            <span className="h-px flex-1 bg-line" />
          </div>

          <button
            onClick={() => void google()}
            className="pressable flex h-13 w-full items-center justify-center gap-3 rounded-2xl border border-line bg-raised text-[15px] font-bold"
          >
            <GoogleMark />
            Continue with Google
          </button>
        </>
      )}

      <button
        onClick={() => {
          setMode((m) => (m === "signin" ? "signup" : "signin"));
          setError(null);
          setNotice(null);
        }}
        className="pressable mt-6 text-center text-sm font-semibold text-muted"
      >
        {mode === "signin" ? (
          <>
            New here? <span className="text-accent">Create an account</span>
          </>
        ) : mode === "signup" ? (
          <>
            Already cooking? <span className="text-accent">Sign in</span>
          </>
        ) : (
          <>
            Remembered it? <span className="text-accent">Back to sign in</span>
          </>
        )}
      </button>
    </div>
  );
}

function Field({
  label,
  type,
  value,
  onChange,
  placeholder,
  minLength,
  maxLength,
}: {
  label: string;
  type: string;
  value: string;
  onChange: (v: string) => void;
  placeholder: string;
  minLength?: number;
  maxLength?: number;
}) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-xs font-bold tracking-wide text-muted uppercase">
        {label}
      </span>
      <input
        type={type}
        required
        value={value}
        minLength={minLength}
        maxLength={maxLength}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="h-13 w-full rounded-2xl border border-line bg-raised px-4 text-[15px] outline-none placeholder:text-faint focus:border-accent"
      />
    </label>
  );
}

function GoogleMark() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden>
      <path
        fill="#4285F4"
        d="M23.5 12.27c0-.85-.08-1.66-.22-2.45H12v4.64h6.46a5.53 5.53 0 0 1-2.4 3.62v3h3.88c2.27-2.1 3.56-5.18 3.56-8.81Z"
      />
      <path
        fill="#34A853"
        d="M12 24c3.24 0 5.96-1.07 7.94-2.91l-3.88-3c-1.08.72-2.45 1.15-4.06 1.15-3.13 0-5.78-2.11-6.72-4.95H1.27v3.09A12 12 0 0 0 12 24Z"
      />
      <path
        fill="#FBBC05"
        d="M5.28 14.29a7.2 7.2 0 0 1 0-4.58V6.62H1.27a12 12 0 0 0 0 10.76l4.01-3.09Z"
      />
      <path
        fill="#EA4335"
        d="M12 4.77c1.76 0 3.35.6 4.6 1.8l3.44-3.44A11.98 11.98 0 0 0 1.27 6.62l4.01 3.09C6.22 6.88 8.87 4.77 12 4.77Z"
      />
    </svg>
  );
}
