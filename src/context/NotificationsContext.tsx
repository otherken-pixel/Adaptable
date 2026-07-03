import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { fetchNotifications, markNotificationsRead } from "@/lib/api";
import { supabase, isDemo } from "@/lib/supabase";
import { subscribeDemoStore } from "@/lib/demo";
import type { AppNotification } from "@/lib/types";
import { useAuth } from "./AuthContext";

interface NotificationsState {
  items: AppNotification[];
  unreadCount: number;
  markAllRead: () => void;
}

const NotificationsContext = createContext<NotificationsState | null>(null);

export function NotificationsProvider({ children }: { children: ReactNode }) {
  const { profile } = useAuth();
  const [items, setItems] = useState<AppNotification[]>([]);

  const refresh = useCallback(() => {
    if (!profile) return;
    fetchNotifications(profile.id)
      .then(setItems)
      .catch(() => {
        /* inbox is non-critical; keep last known state */
      });
  }, [profile]);

  useEffect(() => {
    if (!profile) {
      setItems([]);
      return;
    }
    refresh();

    if (isDemo) {
      // Demo store emits on every mutation (incl. simulated engagement).
      return subscribeDemoStore(refresh);
    }

    // Live mode: Supabase Realtime pushes new rows the instant a DB
    // trigger writes them — no polling, no third-party service.
    const channel = supabase!
      .channel(`notifications:${profile.id}`)
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "notifications",
          filter: `user_id=eq.${profile.id}`,
        },
        () => refresh(),
      )
      .subscribe();

    return () => {
      void supabase!.removeChannel(channel);
    };
  }, [profile, refresh]);

  const markAllRead = useCallback(() => {
    if (!profile) return;
    setItems((prev) => prev.map((n) => ({ ...n, read: true })));
    markNotificationsRead(profile.id).catch(() => {
      /* will self-heal on next refresh */
    });
  }, [profile]);

  const unreadCount = useMemo(() => items.filter((n) => !n.read).length, [items]);

  const value = useMemo(
    () => ({ items, unreadCount, markAllRead }),
    [items, unreadCount, markAllRead],
  );

  return (
    <NotificationsContext.Provider value={value}>
      {children}
    </NotificationsContext.Provider>
  );
}

export function useNotifications(): NotificationsState {
  const ctx = useContext(NotificationsContext);
  if (!ctx) throw new Error("useNotifications must be used within NotificationsProvider");
  return ctx;
}
