import { Capacitor } from "@capacitor/core";
import { registerDeviceToken } from "./api";

export type PushStatus = "enabled" | "denied" | "unsupported";

/**
 * Device push, 100% Supabase + Apple — no Firebase anywhere.
 *
 * iOS: the Capacitor plugin hands back the RAW APNs token (Firebase is
 * never involved on iOS). We store it in the `device_tokens` table and
 * the `push-dispatch` edge function delivers by calling APNs directly.
 *
 * Android: Google only permits background push through its own FCM
 * service, which this project deliberately avoids. Android users get
 * the live in-app Activity inbox (Supabase Realtime) instead.
 */
export async function enablePush(userId: string): Promise<PushStatus> {
  if (Capacitor.getPlatform() !== "ios") return "unsupported";

  const { PushNotifications } = await import("@capacitor/push-notifications");

  let perm = await PushNotifications.checkPermissions();
  if (perm.receive === "prompt" || perm.receive === "prompt-with-rationale") {
    perm = await PushNotifications.requestPermissions();
  }
  if (perm.receive !== "granted") return "denied";

  return new Promise<PushStatus>((resolve) => {
    let settled = false;
    const settle = (status: PushStatus) => {
      if (!settled) {
        settled = true;
        resolve(status);
      }
    };

    void PushNotifications.addListener("registration", (token) => {
      registerDeviceToken(userId, token.value, "ios")
        .then(() => settle("enabled"))
        .catch(() => settle("denied"));
    });
    void PushNotifications.addListener("registrationError", () => settle("denied"));

    void PushNotifications.register();

    // APNs should answer within seconds; don't hang the UI forever.
    setTimeout(() => settle("denied"), 15_000);
  });
}
