# Implementation status · 2026-11-05

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
- On November 3, the current UI was installed on an L60 (Android 13, 360dp wide). The timer card and three single-row quick actions rendered without clipping. One-tap reading timing, pause, resume, stop, and the resulting local record were verified; the test record was then deleted. A separate existing local record remained visible. The device reported usage access as allowed. Today's app foreground total exceeded the independently reported screen-interactive time enough to fail the reader's quality gate, so the app correctly hid that total and now explains why. Live total accuracy and reminder delivery remain unverified by this check.
- A second 360dp visual pass refined the Today timer, top bar, navigation, and Trends hierarchy. The timer remains one tap from the Today card or bottom action. Sunset and morning themes were inspected on the device; a manual history under one minute uses compact seven-day marks and exact seconds instead of an almost empty full-height chart. This was a visual and layout check, not a new validation of device usage totals.
- `dart format .`, `flutter analyze`, `flutter test` (20 tests), and `flutter build apk --debug` passed. Android installs now use a stable debug key and `adb install -r` through `make run-android`; this command fails on a signature mismatch rather than automatically uninstalling an app containing local records.

## Outstanding work before a cross-platform release

1. Install full Xcode, connect an iPhone, obtain the Family Controls capability and distribution entitlement for the app and its report/monitor extensions, then implement and test the protected SwiftUI report, app picker and threshold monitor. Apple's [Family Controls entitlement guide](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement) requires a distribution request for the app and Screen Time API extensions.
2. Validate Android daily/app totals against the system's usage report on multiple devices. Test a saved goal across backgrounding, permission revocation, midnight and reboot. Android [JobScheduler](https://developer.android.com/reference/android/app/job/JobScheduler) scheduling is inexact; do not promise immediate delivery.
3. Validate P2 features with longer real-world use: multiple goals, weekday/weekend limits and the weekly review. The 30-day heatmap cannot fill dates for which the OS provides no trustworthy data.
4. Decide whether optional AI adds value after the non-AI product is validated. No protected iOS report data should be exported to Flutter or a cloud model. Apple's [Device Activity Report](https://developer.apple.com/documentation/deviceactivity/deviceactivityreport) runs in a protected extension.

The local debug APK is for review. The Android release build still uses a debug signing configuration; store release signing and distribution are separate tasks.

## Time journal preview · November 5

- Today now has a compact one-tap timer, category-colored 24-hour ruler and chronological local activity ledger. Pause gaps remain blank and cross-midnight ranges are clipped to the journal day.
- Empty journals offer a separate read-only sample; Web `?preview=journal` opens it directly. Sample activities are ephemeral and never saved to local entries.
- This revision changes the shared Flutter UI, not native usage-data collection or notification delivery.
- `dart format .`, `flutter analyze`, all 22 Flutter tests, `flutter build web`, and `flutter build apk --debug` passed. The added widget checks cover sample isolation and paused records crossing midnight.
- Browser visual checks covered 360- and 390-point phone widths, morning paper and twilight palettes. Screenshots in `docs/journal-home.jpg` and `docs/journal-preview.jpg` contain empty local history or explicitly labeled sample data. Installed on the L60 Android 13 physical device using signature-matched replacement installation. Today, empty history, the read-only sample, category ruler and ledger were visually checked at 360dp. The existing sunset preference remained selected. Device inspection caught identical life/exercise colors in the dark palettes; life and social now have distinct blended hues. No release/profile performance measurement was performed.
