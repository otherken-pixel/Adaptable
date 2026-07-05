# 🍳 Adaptable — native iOS app

A from-scratch, best-in-class native Swift/SwiftUI client for Adaptable,
built to full feature parity with the React web app in `../src`. It talks
to the **same Supabase project** (`ypziulvtfsyrwpotlevp`) as the web app —
same recipes, same votes, same community, same edge functions — so a
recipe generated on the web shows up instantly in the iOS app and vice
versa.

| | |
| --- | --- |
| UI | SwiftUI (iOS 17+), MVVM |
| Backend | [supabase-swift](https://github.com/supabase/supabase-swift) (Postgrest, Auth, Realtime, Storage, Edge Functions) |
| Push | Raw APNs via the existing `push-dispatch` edge function — no Firebase |
| Voice | `Speech` + `AVFoundation` for Cook Mode hands-free commands |
| Auth | Email/password + Google OAuth (`ASWebAuthenticationSession`, handled internally by the SDK) |

## Opening the project

```
open ios/Adaptable/Adaptable.xcodeproj
```

Requirements: **Xcode 16+** on macOS (this project uses Xcode 16's
file-system-synchronized group format, so the folder structure on disk
*is* the project — no file-by-file membership to maintain). On first
open, Xcode resolves the `supabase-swift` Swift Package automatically
(needs network access once).

This project was authored and organized in a Linux sandbox without
Xcode/Swift available, so **it has not been compiled yet**. The code
follows supabase-swift's documented APIs closely, but the SDK's surface
(especially the Realtime `postgresChange` API) has shifted across minor
versions — if the resolved package version differs from what's assumed
here, expect a handful of small, Xcode-quick-fix-able signature tweaks on
the first build. The likeliest spots, in order:

1. `NotificationsStore.swift` — Realtime channel subscription API.
2. `API.swift` — `.execute().value` decode pattern, `FunctionsError` case shape.
3. `AuthStore.swift` — `auth.signIn`, `auth.signUp(data:)`, `authStateChanges`.

## Configuration

`Support/Config.xcconfig` ships with the same Supabase URL + anon key as
`../.env.example` (the anon key is a publishable client key — every table
enforces Row Level Security, so committing it is safe, same as the web
app does). Leave it as-is to hit the live backend, or blank both values
out to boot in **Demo Mode**: a fully interactive local experience seeded
with the same recipes as `src/lib/demo.ts`, persisted to `UserDefaults`,
explorable with zero setup.

## Feature parity checklist

Every screen and feature in the web app has a native counterpart:

- **Discover feed** — Hot (time-decayed trending)/Top/New, search, filter
  chips (For you, Following, time, calories, protein, tags), deterministic
  gradient covers.
- **Create** — Describe / Fridge (pantry) / Import (link, camera photo,
  library photo, pasted text) modes, party-size stepper, remix flow,
  loading/error/done states.
- **Recipe detail** — hero, macro + stat bands, servings scaler
  (fraction-aware quantity scaling), meal-plan day picker, share sheet,
  follow button, comments, community "cooked it" photos.
- **Cook Mode** — mise en place checklist, one-step-at-a-time flow,
  per-step timers that keep running across steps with a heads-up strip,
  voice commands ("next", "back", "ingredients", "start timer") via
  `SFSpeechRecognizer`, screen wake-lock, confetti finish, cooked-it photo
  upload, records a "Cooked it" that feeds Trending.
- **Cookbook** — Saved recipes + Meal Planner tabs; "send the week to
  Groceries" in one tap.
- **Groceries** — grouped by source recipe, check-off, clear done.
- **Activity** — notification inbox, live via Supabase Realtime
  (`postgres_changes` on `public.notifications`).
- **Profile** — avatar upload, stats, username edit, Taste Profile link,
  push-notification opt-in, sign out, delete account.
- **Taste Profile** — diets, allergies (hard safety rule server-side),
  dislikes, household size, spice, skill.
- **Auth** — sign in / sign up / forgot password, Google OAuth, password
  reset via the `com.adaptable.app://reset-password` deep link.
- **Demo Mode** — identical seeded recipes/comments/templates to the web
  app, with the same simulated community engagement (delayed
  notifications after you publish a recipe).

## Push notifications (device push, no Firebase)

Same pipeline as the web app's native builds: DB trigger → `notifications`
row → Database Webhook → `push-dispatch` edge function → APNs directly.
To receive real device pushes:

1. In Xcode, the **Push Notifications** capability is already declared in
   `Support/Adaptable.entitlements` (`aps-environment: development`; flip
   to `production` for a release build/TestFlight).
2. Follow the "`Notifications — the no-Firebase pipeline`" setup steps in
   `../README.md` (APNs auth key, edge function secrets, Database
   Webhook) — it's the same backend, so nothing iOS-specific to deploy.

## Google Sign-In

No separate native Google client ID is needed — `signInWithOAuth` opens
Supabase's hosted `/auth/v1/authorize` page in an ephemeral
`ASWebAuthenticationSession` and redirects back to
`com.adaptable.app://login-callback`, exactly like the web app's redirect
flow. Make sure that redirect URL is allow-listed under **Auth → URL
Configuration** in the Supabase dashboard (see `../README.md`).

## What's intentionally not native-app-first

- Recipe/comment/vote data model, RLS policies and edge functions are
  100% shared with the web app (`../supabase/`) — there is no
  iOS-specific backend.
- Android is out of scope for this task; the existing Capacitor-based
  Android build in the web project is unaffected.
