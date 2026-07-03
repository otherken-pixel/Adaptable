# 🍳 Adaptable

**AI recipes that adapt to you.** Describe what you're craving — dietary
constraints, time limits, whatever's in the fridge — and get a complete,
structured recipe in seconds. Vote on community creations and save the
keepers to your Cookbook.

| Stack | |
| --- | --- |
| Frontend | React 19 + Vite + TypeScript |
| Styling | Tailwind CSS v4 + Lucide icons |
| Mobile | Capacitor (iOS + Android) |
| Backend | Supabase (Postgres, Auth, RLS, Edge Functions) |
| AI | Google Gemini (structured JSON output) |
| Hosting | Vercel (SPA) |

## ✨ Features

- **AI Generator** — chat-style prompt box with suggestion chips, playful
  loading states, and a fully rendered recipe card on completion.
- **Remix** — one tap on any recipe opens the generator pre-loaded with it
  ("make it vegan", "twice as spicy", "air-fryer version"…). The app is
  called Adaptable for a reason.
- **Cook Mode** — full-screen guided cooking: one step at a time in huge
  type, one-tap timers parsed straight from the instructions (beep +
  vibration), an always-available ingredients sheet, a screen wake-lock so
  the phone never sleeps mid-sauté, and a confetti finish that funnels
  straight into voting.
- **Serving scaler** — stepper on every recipe rescales quantities in place
  (fraction-aware: "1 ½ cups" → "2 ¼ cups").
- **Groceries** — add a recipe's ingredients (scaled) to a shopping list,
  grouped by recipe, with check-off, per-recipe progress and a badge on the
  tab bar. Synced via Supabase (`shopping_items`), local in Demo Mode.
- **Pantry mode** — "What's in my fridge": pick ingredients (quick-add
  staples or type your own) and the AI builds the best dish around them,
  minimizing anything you'd have to buy.
- **Discovery Feed** — 🔥 Hot (time-decayed trending), Top and New sorts,
  full-text search plus time and tag filter chips, deterministic gradient
  covers so every card looks designed.
- **Trending algorithm** — Hacker-News-style decay where an actual cook
  counts 3×, a comment 2× and a vote 1×: finishing Cook Mode records a
  "Cooked it" that pushes recipes up the Hot feed.
- **Comments** — public discussion on every recipe (tips, swaps, results),
  with counts denormalized onto recipes by trigger.
- **Voting** — one vote per user per recipe (enforced by a DB primary key),
  optimistic UI, counter maintained by a Postgres trigger.
- **Activity inbox + notifications, 100% Supabase** — DB triggers write a
  `notifications` row when someone votes, comments or cooks your recipe;
  Supabase Realtime streams it to the in-app Activity inbox instantly on
  every platform, and the `push-dispatch` edge function delivers device
  push by calling Apple's APNs directly. No Firebase anywhere.
- **Cookbook** — personal saves, synced live across every screen.
- **Auth** — Supabase email/password + Google OAuth, auto-created profiles.
- **Demo Mode** — no env vars? The app boots with seeded recipes and a local
  store so the whole loop is explorable with zero setup.

## 🚀 Quick start

```bash
npm install
npm run dev          # Demo Mode — no keys needed
```

To go live, copy `.env.example` → `.env` and fill in your Supabase URL +
anon key.

## 🛠 From-scratch initialization (reference)

These are the commands this project was bootstrapped with:

```bash
# 1. React + Vite + TypeScript
npm create vite@latest adaptable -- --template react-ts
cd adaptable

# 2. Tailwind CSS v4 (Vite plugin — no PostCSS config needed)
npm install tailwindcss @tailwindcss/vite
# then add `tailwindcss()` to vite.config.ts plugins
# and `@import "tailwindcss";` at the top of src/index.css

# 3. App dependencies
npm install @supabase/supabase-js react-router-dom lucide-react

# 4. Capacitor (native iOS/Android wrapper)
npm install @capacitor/core @capacitor/ios @capacitor/android
npm install -D @capacitor/cli
npx cap init Adaptable com.adaptable.app --web-dir=dist
npm run build
npx cap add ios        # requires Xcode (macOS)
npx cap add android    # requires Android Studio
npx cap sync
```

## 🗄 Supabase setup

1. Create a project at [database.new](https://database.new).
2. Run the migration in `supabase/migrations/20260703000000_init.sql`
   (SQL Editor → paste → run), or with the CLI:
   ```bash
   supabase link --project-ref <your-ref>
   supabase db push
   ```
3. Deploy the Gemini edge function and set its secret — **the Gemini key
   never touches the client**:
   ```bash
   supabase functions deploy generate-recipe
   supabase secrets set GEMINI_API_KEY=<your-gemini-key>
   ```
4. Enable the Google provider under **Auth → Providers** for OAuth.

### Schema at a glance

| Table | Purpose | Key rules (RLS) |
| --- | --- | --- |
| `profiles` | 1:1 with `auth.users`, auto-created by trigger | Public read, owner write |
| `recipes` | Structured Gemini output + `net_upvotes` counter | Public read, author insert/update/delete |
| `user_votes` | One row per (user, recipe), value ∈ {-1, 1} | Owner only; trigger syncs `recipes.net_upvotes` |
| `saves` | Personal cookbook junction table | Owner only |
| `shopping_items` | Grocery list rows, linked to source recipe | Owner only |
| `comments` | Recipe discussion; trigger syncs `recipes.comment_count` | Public read, owner write |
| `cooks` | One row per finished Cook Mode session; trigger syncs `recipes.cook_count` | Owner only |
| `notifications` | Inbox rows written by DB triggers on votes/comments/cooks; streamed via Realtime | Owner read/update; no client insert |
| `device_tokens` | Raw APNs push tokens per user | Owner only |

### Notifications — the no-Firebase pipeline

Everything runs inside Supabase (plus Apple's own APNs for iOS device
push):

```
vote / comment / cook INSERT
        │  (security-definer trigger)
        ▼
public.notifications row
        ├──► Supabase Realtime ──► in-app Activity inbox (web, iOS, Android)
        └──► Database Webhook ──► push-dispatch edge function ──► APNs (iOS)
```

Setup for device push (iOS):

1. In Xcode, enable the Push Notifications capability and create an APNs
   auth key (.p8) in your Apple Developer account.
2. Set the edge function secrets:
   ```bash
   supabase secrets set \
     APNS_AUTH_KEY="$(cat AuthKey_XXXXXXXXXX.p8)" \
     APNS_KEY_ID=XXXXXXXXXX \
     APNS_TEAM_ID=YYYYYYYYYY \
     APNS_BUNDLE_ID=com.adaptable.app \
     PUSH_WEBHOOK_SECRET=$(openssl rand -hex 24)
   supabase functions deploy push-dispatch --no-verify-jwt
   ```
3. Create a Database Webhook (Dashboard → Database → Webhooks) on
   `INSERT` into `public.notifications`, pointing at the `push-dispatch`
   function URL, with header `x-webhook-secret: <PUSH_WEBHOOK_SECRET>`.

Android note: Google only allows background push through its FCM
service. Since this project is Firebase-free by design, Android users
get the live Activity inbox over Supabase Realtime instead (delivered
whenever the app is open).

## 📱 Native builds

```bash
npm run cap:ios      # build web → sync → open Xcode
npm run cap:android  # build web → sync → open Android Studio
```

The UI is designed mobile-first: bottom tab navigation, 44pt+ touch
targets, safe-area padding (`viewport-fit=cover`), and light/dark themes
that follow the system.

## 🔐 Security notes

- Gemini API key lives only in Supabase Edge Function secrets.
- The edge function forwards the caller's JWT to Postgres, so recipe
  inserts run under the user's identity and RLS policies.
- Vote counts are maintained by a `security definer` trigger — clients
  can never write `net_upvotes` directly.
