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
        options: { data: { username } },
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

  const value = useMemo(
    () => ({
      profile,
      loading,
      isDemo,
      signInWithPassword,
      signUp,
      signInWithGoogle,
      signOut,
    }),
    [profile, loading, signInWithPassword, signUp, signInWithGoogle, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
