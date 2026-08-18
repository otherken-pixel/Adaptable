# Cook timer Live Activity

This folder is **not** part of the main app target (Xcode’s synchronized
`Adaptable/` group). The app already starts `CookTimerAttributes`
activities and posts lock-screen timer notifications.

To show the countdown on the Lock Screen and Dynamic Island:

1. Xcode → File → New → Target → Widget Extension.
2. Enable **Include Live Activity**.
3. Add `CookTimerLiveActivityWidget.swift` (this folder) and
   `Adaptable/Services/CookTimerAttributes.swift` to the widget target.
4. Confirm `NSSupportsLiveActivities` is true (already set on the app).
