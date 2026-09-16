# Cook timer Live Activity

The compiled widget extension is `AdaptableWidgets`. `CookTimerLiveActivityWidget`
and a matching `CookTimerAttributes` copy now live in `../Widgets/` and ship in
that target — do not leave this folder as the only copy.

`Adaptable/Services/CookTimerAttributes.swift` (app) and
`Widgets/CookTimerAttributes.swift` (extension) must stay identical so ActivityKit
can decode the activity the app starts.

Archive / TestFlight: Xcode 27 (iOS 27 SDK).
