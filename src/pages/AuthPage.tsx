import { useState, type FormEvent } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { ChefHat, Loader2 } from "lucide-react";
import { useAuth } from "@/context/AuthContext";

type Mode = "signin" | "signup" | "forgot";

function safeNext(raw: string | null): string | null {
  if (!raw || !raw.startsWith("/") || raw.startsWith("//")) return null;
  return raw;
}

export default function AuthPage() {
  const { signInWithPassword, signUp, requestPasswordReset } = useAuth();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const next = safeNext(params.get("next"));
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
        if (next) navigate(next, { replace: true });
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

  return (
    <div className="mx-auto flex min-h-dvh max-w-lg flex-col justify-center px-6 pt-safe pb-safe">
      <div className="animate-fade-up flex flex-col items-center pb-8 text-center">
        <Link to="/" aria-label="Adaptable home">
          <div
            className="flex h-20 w-20 animate-float items-center justify-center rounded-3xl shadow-xl shadow-accent/25"
            style={{
              background:
                "linear-gradient(135deg, #fb923c 0%, #ea580c 55%, #dc2626 120%)",
            }}
          >
            <ChefHat size={38} className="text-white" strokeWidth={2} />
          </div>
        </Link>
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

      <p className="mt-6 text-center text-[12px] text-faint">
        <Link to="/privacy" className="font-semibold text-muted underline-offset-2 hover:underline">
          Privacy
        </Link>
        {" · "}
        <Link to="/terms" className="font-semibold text-muted underline-offset-2 hover:underline">
          Terms
        </Link>
        {" · "}
        <Link to="/support" className="font-semibold text-muted underline-offset-2 hover:underline">
          Support
        </Link>
      </p>

      <button
        onClick={() => {
          setMode((m) => (m === "signin" ? "signup" : "signin"));
          setError(null);
          setNotice(null);
        }}
        className="pressable mt-4 text-center text-sm font-semibold text-muted"
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
