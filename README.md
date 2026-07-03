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

## ✨ MVP features

- **AI Generator** — chat-style prompt box with suggestion chips, playful
  loading states, and a fully rendered recipe card on completion.
- **Discovery Feed** — community recipes sorted by net upvotes (or newest),
  with deterministic gradient covers so every card looks designed.
- **Voting** — one vote per user per recipe (enforced by a DB primary key),
  optimistic UI, counter maintained by a Postgres trigger.
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
