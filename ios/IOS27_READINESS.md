# Spec C — iOS 27 must+should (source-side)

Ken approved IMPLEMENT against Spec. This file is the readiness / proof
record. **No PR.** Branch only until Ken says ship + proof.

## Branch

`cursor/ios-27-sdk-readiness-2523`

## Environment blocker (Archive + screenshots)

This work ran on a **Cursor cloud Linux VM**. No Xcode, no iOS Simulator,
no Mac pool, no self-hosted Mac worker.

| Acceptance item | Status |
| --- | --- |
| Archive builds with Xcode 27 | **BLOCKED** — needs a Mac with Xcode 27. Source is pointed at Xcode 27 (`LastUpgradeCheck` / scheme `LastUpgradeVersion` = 2700). |
| Launch OK on iOS 27 SDK build | **Code review only** — `AdaptableApp` still has a single `WindowGroup` hosting `RootView`. Not executed here. |
| Screenshot proof | **BLOCKED** — Ken must capture on a device or Simulator (list below). |
| No client secrets / StoreKit keys in source | **PASS** — no IAP `.p8`, no App Store shared secret, no invented StoreKit keys. `Support/Config.xcconfig` still has only the publishable Supabase anon key. |

### Ken next (Mac)

1. Open `ios/Adaptable/Adaptable.xcodeproj` in **Xcode 27**.
2. Resolve `supabase-swift` if asked.
3. Product → Archive (Release, `Adaptable` scheme) for TestFlight.
4. Run on an **iOS 27** Simulator or device and capture the screens below.
5. If Archive fails, paste the first compile errors back — this pass only
   fixed source-side fallout we can see without the SDK.

Do **not** set `UIDesignRequiresCompatibility`. Cook Mode and widgets are
meant to run as iOS 27 Liquid Glass, with opaque kitchen chrome pinned.

## WindowGroup launch review

`ios/Adaptable/Adaptable/App/AdaptableApp.swift`

- `@main struct AdaptableApp: App` exposes **one** `WindowGroup`.
- Root is `RootView` plus the existing store / deep-link / network
  environment objects and the same `.task` / `.onOpenURL` launch path.
- Added `Theme.surface.ignoresSafeArea()` on the scene root so the first
  frame is not a transparent glass hole while auth/profile loads.
- No extra `Window` / document scenes (out of scope). No StoreKit keys
  were added to the scene.

SwiftUI scene was already the right shape; this is confirm + opaque root.

## Source-side changes

1. **Xcode 27 project / Archive pointer**
   - `LastUpgradeCheck` and `LastSwiftUpdateCheck` → `2700`
   - Scheme `LastUpgradeVersion` → `2700`
   - `DEAD_CODE_STRIPPING = YES` (recommended settings leftover)
   - Deployment target stays **iOS 17.0** (SDK deadline ≠ min iOS)
   - Swift language mode stays **5.0** (avoids a Swift 6 concurrency rewrite)
   - `ios/README.md` + `Config.xcconfig` say Archive/TestFlight = Xcode 27

2. **Compile-only deprecated API**
   - Replaced every `navigationBarHidden(true)` with
     `toolbarVisibility(.hidden, for: .navigationBar)` (iOS 18+) /
     `toolbar(.hidden, for: .navigationBar)` (iOS 17)
   - Cook Mode tab bar hide uses the same helper
   - Helpers live in `Adaptable/Theme/KitchenChrome.swift`

3. **Cook Mode + recipe chrome materials**
   - Opaque `Theme.surface` on Cook Mode top bar, bottom step controls,
     ingredients sheet, Adapt sheet, recipe header, and plan sheet
   - iPad inspector fill is opaque `Theme.sunken` (was 35% — washes out
     under glass)
   - `scrollEdgeEffectStyle(.hard)` on cook `ScrollView`s when iOS 26+
   - Recipe “Start Cooking” CTA was already an opaque gradient; left as-is

4. **Widgets / Live Activities**
   - Tonight widget no longer uses `.fill.tertiary` (glass washout)
   - Lock-screen activities use an opaque warm-dark fill + white type
   - `CookTimerLiveActivityWidget` is now **in the compiled**
     `AdaptableWidgets` bundle (it was a drop-in folder and never shipped)
   - `Widgets/CookTimerAttributes.swift` must stay identical to
     `Adaptable/Services/CookTimerAttributes.swift`

## Screens Ken must capture (device or iOS 27 Simulator)

Capture **light and dark** if time allows. Minimum is light.

1. **Cold launch** — splash or Discover after `WindowGroup` comes up.
2. **Recipe chrome** — any recipe detail: hero, stat/macro bands,
   **Start Cooking** button. Confirm type is not glass-washed.
3. **Cook Mode step UI** — a mid-recipe step with:
   - “STEP N OF M”
   - action list
   - at least one timer card
   - **Next step** bar
4. **Cook Mode ingredients sheet** (list button) — readable on glass inset
   sheet.
5. **One of:**
   - Home Screen **Tonight** widget (small or medium), or
   - Lock Screen / Dynamic Island **Live Activity** with a running timer
     (start a cook timer, leave the app).

Optional: iPad Cook Mode two-column inspector.

## Out of scope (not done)

Kitchen App Intents deepening, Duo, Foundation Models, other apps,
Supabase schema.

## Proof paths (this repo)

- This file: `ios/IOS27_READINESS.md`
- Scene: `ios/Adaptable/Adaptable/App/AdaptableApp.swift`
- Chrome helpers: `ios/Adaptable/Adaptable/Theme/KitchenChrome.swift`
- Cook Mode: `ios/Adaptable/Adaptable/Views/CookMode/CookModeView.swift`
- Recipe header: `ios/Adaptable/Adaptable/Views/RecipeDetail/RecipeDetailView.swift`
- Widgets: `ios/Adaptable/Widgets/AdaptableWidgets.swift`
- Widget materials: `ios/Adaptable/Widgets/KitchenWidgetChrome.swift`
- Timer Live Activity UI: `ios/Adaptable/Widgets/CookTimerLiveActivityWidget.swift`
- Project: `ios/Adaptable/Adaptable.xcodeproj/project.pbxproj`
- Scheme: `ios/Adaptable/Adaptable.xcodeproj/xcshareddata/xcschemes/Adaptable.xcscheme`
