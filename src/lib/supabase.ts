import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

/**
 * When Supabase env vars are missing the app runs in Demo Mode:
 * a fully interactive local experience backed by seeded data, so the
 * product is explorable on day one without any backend configured.
 */
export const isDemo = !url || !anonKey;

export const supabase: SupabaseClient | null = isDemo
  ? null
  : createClient(url!, anonKey!);
