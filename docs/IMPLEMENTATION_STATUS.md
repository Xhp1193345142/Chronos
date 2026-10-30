# Implementation status · 2026-10-30

This page records what the repository can actually do. [FUNCTIONAL_SPEC.md](FUNCTIONAL_SPEC.md) remains the product target.

| Area | Android | iOS |
| --- | --- | --- |
| Manual timer | Shared Flutter one-tap timer, pause/resume/stop, categories, notes, backfill/edit/delete, daily strip and seven-day total; persists locally and restores after restart. Works without usage permission. Web demo uses local browser storage. | Shared Flutter UI and local timer code are present; not tested on an iPhone. |
| Permission and data state | Usage access gateway, refresh after returning from settings, denied/empty/partial states; tested on one Android 13 device. | Native Family Controls bridge and entitlement are not configured. The app offers a clearly labeled demo after showing an unavailable state. |
| Today | Real app foreground totals and ranked apps. Hourly bars appear only when event-derived and aggregate durations agree. | Demo only. Protected report charts must be built in a Device Activity Report extension. |
| Trends | Seven daily totals, date selection, app detail, seven-day hourly strip when events are reliable, completed-day baseline, 30-day heatmap, evidence-linked fact card and a review of trustworthy completed days. Unreliable dates are excluded from ranking and baselines. | Demo only. |
| Goals | Multiple local combined app limits, 15-minute steps, optional weekend limits, three reviewed tones, independent enable/disable, pause until tomorrow, edit and local deletion. Existing single-goal data is migrated. | Not connected to FamilyActivityPicker or Device Activity monitoring. |
| Reminders | Periodic JobScheduler check, at most one notification per goal per local date, only after notification permission. APK compiles; actual threshold delivery and reboot persistence remain unverified. | Not implemented. |
| Insight controls | In-app week-range fact, 30-day suppression, global switch; never changes a user goal. | Demo only. |
| Appearance | Three shared Flutter palettes plus follow-system mode, local preference persistence, themed charts and semantic warning colors. | Shared demo UI uses the same appearance picker; native report UI is not built yet. |
| Visual hierarchy | Today uses one primary duration card, open chart sections, and reduced-motion-aware chart selection. Trends uses tonal hourly strips and a labeled average rule; app rankings use a neutral numbered ledger instead of arbitrary colors. Goals retains distinct summary and control groups. Platform launcher icons share the Chronos mark. Unavailable hourly data stays explicitly labeled. | Shared demo UI and app icon receive the same visual system; native iOS data is still unavailable. |
| AI | No AI calls by design. The spec requires a separate privacy and feasibility decision before P3. | Same. |

## Android validation

- A debug APK built and installed on an Android 13 physical device. The user granted usage access through system settings; Chronos then displayed real app labels, today's total and trend pages.
- The device returned some historical app durations close to 24 hours. The reader now checks app foreground totals against Android screen-interactive event totals; inconsistent dates display as unavailable and do not affect insights. This is a conservative quality gate, not a substitute for comparing figures with the device's system Screen Time report.
- Goal editor appearance and app selection list were inspected on the physical device. Two disabled temporary goals were saved and shown separately, then deleted. Notification permission was not requested; background threshold delivery, timezone changes, and reboot persistence remain unverified.
- The appearance picker, all three palettes, and follow-system restoration were inspected on the Android 13 physical device.
- `dart format .`, `flutter analyze`, `flutter test` (18 tests), `flutter build apk --debug`, and `flutter build web` passed for the manual-timer change. The updated APK was not installed over the existing app because its debug signature differs; the new timer remains unverified on a physical device. See the latest `dev` CI result for the pushed commit.

## Outstanding work before a cross-platform release

1. Install full Xcode, connect an iPhone, obtain the Family Controls capability and distribution entitlement for the app and its report/monitor extensions, then implement and test the protected SwiftUI report, app picker and threshold monitor. Apple's [Family Controls entitlement guide](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement) requires a distribution request for the app and Screen Time API extensions.
2. Validate Android daily/app totals against the system's usage report on multiple devices. Test a saved goal across backgrounding, permission revocation, midnight and reboot. Android [JobScheduler](https://developer.android.com/reference/android/app/job/JobScheduler) scheduling is inexact; do not promise immediate delivery.
3. Validate P2 features with longer real-world use: multiple goals, weekday/weekend limits and the weekly review. The 30-day heatmap cannot fill dates for which the OS provides no trustworthy data.
4. Decide whether optional AI adds value after the non-AI product is validated. No protected iOS report data should be exported to Flutter or a cloud model. Apple's [Device Activity Report](https://developer.apple.com/documentation/deviceactivity/deviceactivityreport) runs in a protected extension.

The local debug APK is for review. The Android release build still uses a debug signing configuration; store release signing and distribution are separate tasks.
