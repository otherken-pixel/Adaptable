import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts";

/**
 * Supabase Edge Function to dispatch Apple Push Notifications (APNs).
 * Requires the following Supabase Secrets:
 * - APNS_PRIVATE_KEY: The contents of the .p8 file
 * - APNS_KEY_ID: The 10-character Key ID
 * - APNS_TEAM_ID: The 10-character Apple Team ID
 * - APNS_BUNDLE_ID: e.g., com.adaptable.app
 */

const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!;
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID")!;

serve(async (req) => {
  try {
    const { deviceToken, isSandbox, title, body, customData } = await req.json();

    if (!deviceToken || !title || !body) {
      return new Response("Missing required fields", { status: 400 });
    }

    // Generate JWT token using djwt
    const jwt = await create(
      { alg: "ES256", kid: APNS_KEY_ID },
      {
        iss: APNS_TEAM_ID,
        iat: getNumericDate(0), // Issued at (now)
      },
      APNS_PRIVATE_KEY
    );

    // APNs JSON Payload structure
    const payload = {
      aps: {
        alert: {
          title: title,
          body: body,
        },
        sound: "default",
      },
      ...customData, // Append custom recipe ID or action types outside of 'aps'
    };

    // Determine the environment based on client flag
    const host = isSandbox
      ? "api.sandbox.push.apple.com"
      : "api.push.apple.com";
    
    const url = `https://${host}/3/device/${deviceToken}`;

    // Execute HTTP/2 request to Apple
    const apnsResponse = await fetch(url, {
      method: "POST",
      headers: {
        "authorization": `bearer ${jwt}`,
        "apns-topic": APNS_BUNDLE_ID,
        "apns-push-type": "alert", // required for alert notifications
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (apnsResponse.status === 200) {
      return new Response(JSON.stringify({ success: true }), {
        headers: { "Content-Type": "application/json" },
      });
    } else {
      const errorText = await apnsResponse.text();
      console.error("APNs Error:", errorText);
      return new Response(JSON.stringify({ success: false, error: errorText }), {
        status: apnsResponse.status,
        headers: { "Content-Type": "application/json" },
      });
    }
  } catch (error) {
    console.error("Edge Function Error:", error);
    return new Response("Internal Server Error", { status: 500 });
  }
});
