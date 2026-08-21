// Rewrites one cook step when the user is out of an ingredient.

import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  extractAllergies,
  findAllergyViolations,
} from "../_shared/safety.ts";
import { geminiIsolatedPayload, untrustedBlock } from "../_shared/prompt.ts";

const GEMINI_MODELS = [
  "gemini-2.5-flash",
  "gemini-2.5-flash-lite",
  "gemini-flash-latest",
];

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const schema = {
  type: "OBJECT",
  properties: {
    instruction: { type: "STRING" },
    tip: { type: "STRING" },
    substitute: { type: "STRING" },
  },
  required: ["instruction"],
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "You must be signed in to adapt a step." }, 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return json({ error: "You must be signed in to adapt a step." }, 401);
    }

    const { data: profileRow } = await supabase
      .from("profiles")
      .select("preferences")
      .eq("id", user.id)
      .maybeSingle();
    const allergies = extractAllergies(profileRow?.preferences);

    const body = await req.json().catch(() => null);
    const missing = typeof body?.missing === "string" ? body.missing.trim() : "";
    const instruction = typeof body?.instruction === "string" ? body.instruction : "";
    const title = typeof body?.recipe_title === "string" ? body.recipe_title : "this dish";
    if (!missing || missing.length > 80) {
      return json({ error: "Tell us what you ran out of." }, 400);
    }

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) return json({ error: "Recipe engine is not configured." }, 500);

    const allergyRule = allergies.length > 0
      ? ` STRICT SAFETY RULE — do not use ${allergies.join(", ")} or any derivative.`
      : "";

    const system =
      "The cook is out of one ingredient. Rewrite the original step so it still works without that ingredient. " +
      "Keep it one short instruction a beginner can follow. Return a substitute name if one is obvious." +
      allergyRule;

    const payload = geminiIsolatedPayload({
      system,
      userParts: [{
        text: [
          untrustedBlock("recipe title", title),
          untrustedBlock("missing ingredient", missing),
          untrustedBlock("original step", instruction),
        ].join("\n"),
      }],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: schema,
        temperature: allergies.length > 0 ? 0.3 : 0.4,
      },
    });

    let last = "";
    for (const model of GEMINI_MODELS) {
      const url =
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiKey}`;
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      if (res.status === 404) continue;
      if (!res.ok) {
        last = await res.text();
        break;
      }
      const data = await res.json();
      const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (typeof text !== "string") continue;
      let parsed: { instruction?: string; tip?: string; substitute?: string };
      try {
        parsed = JSON.parse(text);
      } catch {
        continue;
      }
      const adapt = {
        instruction: String(parsed.instruction ?? instruction),
        tip: parsed.tip ? String(parsed.tip) : null,
        substitute: parsed.substitute ? String(parsed.substitute) : missing,
      };
      const hits = findAllergyViolations(
        {
          title,
          ingredients: [{ item: adapt.substitute ?? "", note: "" }],
          steps: [{ instruction: adapt.instruction, tip: adapt.tip ?? "" }],
        },
        allergies,
      );
      if (hits.length > 0) {
        return json(
          {
            error:
              `We blocked that swap because it still looked like it contained ${hits.join(", ")}.`,
          },
          422,
        );
      }
      return json({ adapt }, 200);
    }
    console.error("adapt-step failed", last.slice(0, 300));
    return json({ error: "Couldn't adapt that step — try again." }, 502);
  } catch (e) {
    console.error("adapt-step", e);
    return json({ error: "Couldn't adapt that step — try again." }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
