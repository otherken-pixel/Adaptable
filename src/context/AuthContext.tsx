import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { supabase, isDemo } from "@/lib/supabase";
import { DEMO_USER } from "@/lib/demo";
import type { Profile } from "@/lib/types";

interface AuthState {
  /** Signed-in user's profile (or the demo user in Demo Mode). */
  profile: Profile | null;
  loading: boolean;
  isDemo: boolean;
  signInWithPassword: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string, username: string) => Promise<void>;
  signInWithGoogle: () => Promise<void>;
  signOut: () => Promise<void>;
  /** Emails a recovery link that lands on /reset-password. */
  requestPasswordReset: (email: string) => Promise<void>;
  /** Sets a new password for the current (recovery) session. */
  updatePassword: (newPassword: string) => Promise<void>;
  /** Renames the profile; throws "That username is taken" on conflict. */
  updateUsername: (username: string) => Promise<void>;
  /** Permanently deletes the account via the delete-account edge function. */
  deleteAccount: () => Promise<void>;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [profile, setProfile] = useState<Profile | null>(isDemo ? DEMO_USER : null);
  const [loading, setLoading] = useState(!isDemo);

  useEffect(() => {
    if (isDemo) return;

    let cancelled = false;

    async function loadProfile(userId: string) {
      const { data } = await supabase!
        .from("profiles")
        .select("*")
        .eq("id", userId)
        .maybeSingle();
      if (!cancelled) {
        setProfile((data as Profile) ?? null);
        setLoading(false);
      }
    }

    supabase!.auth.getSession().then(({ data: { session } }) => {
      if (session?.user) loadProfile(session.user.id);
      else if (!cancelled) setLoading(false);
    });

    const { data: sub } = supabase!.auth.onAuthStateChange((_event, session) => {
      if (session?.user) loadProfile(session.user.id);
      else {
        setProfile(null);
        setLoading(false);
      }
    });

    return () => {
      cancelled = true;
      sub.subscription.unsubscribe();
    };
  }, []);

  const signInWithPassword = useCallback(async (email: string, password: string) => {
    const { error } = await supabase!.auth.signInWithPassword({ email, password });
    if (error) throw error;
  }, []);

  const signUp = useCallback(
    async (email: string, password: string, username: string) => {
      const { error } = await supabase!.auth.signUp({
        email,
        password,
        options: {
          data: { username },
          emailRedirectTo: window.location.origin,
        },
      });
      if (error) throw error;
    },
    [],
  );

  const signInWithGoogle = useCallback(async () => {
    const { error } = await supabase!.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: window.location.origin },
    });
    if (error) throw error;
  }, []);

  const signOut = useCallback(async () => {
    if (isDemo) return;
    await supabase!.auth.signOut();
  }, []);

  const requestPasswordReset = useCallback(async (email: string) => {
    if (isDemo) return;
    const { error } = await supabase!.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    });
    if (error) throw error;
  }, []);

  const updatePassword = useCallback(async (newPassword: string) => {
    if (isDemo) return;
    const { error } = await supabase!.auth.updateUser({ password: newPassword });
    if (error) throw error;
  }, []);

  const updateUsername = useCallback(
    async (username: string) => {
      const clean = username.trim();
      if (clean.length < 3 || clean.length > 24) {
        throw new Error("Username must be 3–24 characters.");
      }
      if (isDemo) {
        setProfile((p) => (p ? { ...p, username: clean } : p));
        return;
      }
      if (!profile) return;
      const { error } = await supabase!
        .from("profiles")
        .update({ username: clean })
        .eq("id", profile.id);
      if (error) {
        throw new Error(
          error.code === "23505" ? "That username is taken." : error.message,
        );
      }
      setProfile((p) => (p ? { ...p, username: clean } : p));
    },
    [profile],
  );

  const deleteAccount = useCallback(async () => {
    if (isDemo) return;
    const { data, error } = await supabase!.functions.invoke("delete-account");
    if (error) throw new Error(error.message ?? "Deletion failed");
    if (data?.error) throw new Error(data.error);
    await supabase!.auth.signOut();
  }, []);

  const value = useMemo(
    () => ({
      profile,
      loading,
      isDemo,
      signInWithPassword,
      signUp,
      signInWithGoogle,
      signOut,
      requestPasswordReset,
      updatePassword,
      updateUsername,
      deleteAccount,
    }),
    [
      profile,
      loading,
      signInWithPassword,
      signUp,
      signInWithGoogle,
      signOut,
      requestPasswordReset,
      updatePassword,
      updateUsername,
      deleteAccount,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
