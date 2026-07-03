import { Capacitor } from "@capacitor/core";
import { registerDeviceToken } from "./api";

export type PushStatus = "enabled" | "denied" | "unsupported";

/**
 * Enable push notifications on native builds (iOS/Android via Capacitor).
 * On the web this is a graceful no-op — tokens only exist in the apps.
 * Delivery is server-side: an edge function reads device_tokens and sends
 * through FCM/APNs.
 */
export async function enablePush(userId: string): Promise<PushStatus> {
  if (!Capacitor.isNativePlatform()) return "unsupported";

  const { PushNotifications } = await import("@capacitor/push-notifications");

  let perm = await PushNotifications.checkPermissions();
  if (perm.receive === "prompt" || perm.receive === "prompt-with-rationale") {
    perm = await PushNotifications.requestPermissions();
  }
  if (perm.receive !== "granted") return "denied";

  const platform = Capacitor.getPlatform() as "ios" | "android";

  return new Promise<PushStatus>((resolve) => {
    let settled = false;
    const settle = (status: PushStatus) => {
      if (!settled) {
        settled = true;
        resolve(status);
      }
    };

    void PushNotifications.addListener("registration", (token) => {
      registerDeviceToken(userId, token.value, platform)
        .then(() => settle("enabled"))
        .catch(() => settle("denied"));
    });
    void PushNotifications.addListener("registrationError", () => settle("denied"));

    void PushNotifications.register();

    // APNs/FCM should answer within seconds; don't hang the UI forever.
    setTimeout(() => settle("denied"), 15_000);
  });
}
