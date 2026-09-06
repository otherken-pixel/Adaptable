// Supabase Edge Function: delete-account
//
// Permanently deletes the calling user's account. The caller is
// identified strictly from their JWT; the service-role client is used
// for storage cleanup, leftover household cleanup, and the final
// auth.admin delete. Every app table references profiles with
// ON DELETE CASCADE, so recipes, votes, saves, comments, cooks,
// shopping items, notifications and device tokens all go too.
//
// Extra hygiene (best-effort, never blocks deletion):
//   - remove storage objects in recipe-covers / cook-photos / avatars
//   - leave_household + delete empty leftover households
//
// Required for App Store review (account deletion must be in-app).
// Demo Mode clients no-op and never call this function.

import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const USER_BUCKETS = ["recipe-covers", "cook-photos", "avatars"] as const;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const caller = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      },
    );

    const { data: { user }, error: authError } = await caller.auth.getUser();
    if (authError || !user) {
      return json({ error: "You must be signed in." }, 401);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    await deleteUserStorage(admin, user.id);
    await leaveAndSweepHousehold(caller, admin, user.id);

    const { error } = await admin.auth.admin.deleteUser(user.id);
    if (error) {
      console.error("delete-account failed", user.id, error);
      return json({ error: "Could not delete the account. Try again." }, 500);
    }

    return json({ success: true }, 200);
  } catch (err) {
    console.error("delete-account error", err);
    return json({ error: "Unexpected error." }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Best-effort: wipe the user's prefix in each public media bucket. */
async function deleteUserStorage(
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
): Promise<void> {
  for (const bucket of USER_BUCKETS) {
    try {
      await removePrefix(admin, bucket, userId);
    } catch (e) {
      console.error("storage cleanup failed", bucket, userId, e);
    }
  }
}

async function removePrefix(
  // deno-lint-ignore no-explicit-any
  admin: any,
  bucket: string,
  prefix: string,
): Promise<void> {
  let offset = 0;
  const files: string[] = [];
  for (;;) {
    const { data, error } = await admin.storage.from(bucket).list(prefix, {
      limit: 1000,
      offset,
    });
    if (error) {
      console.error("storage list failed", bucket, prefix, error);
      break;
    }
    const batch = data ?? [];
    if (batch.length === 0) break;
    for (const item of batch) {
      if (!item?.name) continue;
      const path = `${prefix}/${item.name}`;
      const isFolder = item.id == null || item.metadata == null;
      if (isFolder) {
        await removePrefix(admin, bucket, path);
      } else {
        files.push(path);
      }
    }
    if (batch.length < 1000) break;
    offset += 1000;
  }
  if (files.length > 0) {
    const { error: rmErr } = await admin.storage.from(bucket).remove(files);
    if (rmErr) console.error("storage remove failed", bucket, rmErr);
  }
}

/**
 * Prefer the hardened leave_household RPC (owner promotion + empty delete)
 * while the JWT is still valid, then admin-sweep leftovers.
 */
async function leaveAndSweepHousehold(
  // deno-lint-ignore no-explicit-any
  caller: any,
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
): Promise<void> {
  try {
    const { error } = await caller.rpc("leave_household");
    if (error) console.error("leave_household rpc failed", error);
  } catch (e) {
    console.error("leave_household rpc threw", e);
  }

  try {
    await sweepLeftoverHouseholds(admin, userId);
  } catch (e) {
    console.error("household sweep failed", userId, e);
  }
}

async function sweepLeftoverHouseholds(
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
): Promise<void> {
  const householdIds = new Set<string>();

  const { data: memberships, error: memErr } = await admin
    .from("household_members")
    .select("household_id")
    .eq("user_id", userId);
  if (memErr) {
    console.error("household membership read failed", memErr);
  } else {
    for (const row of memberships ?? []) {
      if (row?.household_id) householdIds.add(String(row.household_id));
    }
  }

  const { data: profile } = await admin
    .from("profiles")
    .select("household_id")
    .eq("id", userId)
    .maybeSingle();
  if (profile?.household_id) householdIds.add(String(profile.household_id));

  if (householdIds.size === 0) return;

  await admin.from("household_members").delete().eq("user_id", userId);
  await admin.from("profiles").update({ household_id: null }).eq("id", userId);

  for (const hid of householdIds) {
    const { count, error } = await admin
      .from("household_members")
      .select("user_id", { count: "exact", head: true })
      .eq("household_id", hid);
    if (error) {
      console.error("household member count failed", hid, error);
      continue;
    }
    if ((count ?? 0) === 0) {
      const { error: delErr } = await admin.from("households").delete().eq(
        "id",
        hid,
      );
      if (delErr) console.error("empty household delete failed", hid, delErr);
    }
  }
}
