# Technical architecture

## Chosen stack

- Flutter/Dart for shared navigation, design system, settings, and UI that can use shared data.
- Swift for Family Controls, Device Activity monitoring, and the iOS Device Activity Report extension. Apple's report extension renders its own SwiftUI content in a protected sandbox.
- Kotlin for Android UsageStatsManager integration and background goal checks.
- Local storage for goals, preferences, and permissible summaries. No backend in the first release.
- A shared Flutter manual-timer domain, independent of the platform screen-time adapters.
- Flutter `ThemeExtension` tokens and a locally stored appearance choice for all shared UI; system mode maps light and dark appearances without changing usage data or goals.

## Boundaries

The Flutter domain layer describes goals and display state. A platform capability layer reports whether usage access is available, supports app selection, configures threshold monitoring, and presents a report. It does **not** promise that both platforms return identical raw usage records.

On iOS, the user selects apps through FamilyActivityPicker; Device Activity monitors thresholds; DeviceActivityReport renders usage charts within its extension. Do not copy sensitive report data into Flutter or send it to a server. The distribution entitlement must be approved before release.

On Android, UsageStatsManager reads permitted app statistics after the user enables usage access. Background checks may be delayed by operating-system scheduling; reminder copy must not imply exact-to-the-minute triggering.

## Current implementation

Android's `UsageReader` runs behind the `chronos/native` method channel and returns dated snapshots with explicit `available` and `reason` fields. It cross-checks aggregate app foreground time against screen-interactive time and suppresses clearly inconsistent dates. `GoalStore` keeps multiple local goals and insight preferences in private SharedPreferences, migrating the earlier single-goal format. `GoalCheckJobService` schedules inexact periodic checks through JobScheduler and sends at most one notification per goal per local date. The Flutter live pages never replace a permission or loading failure with demo values.

`lib/demo_data.dart` still provides fixed, deterministic data for Web previews and the optional on-device demo. It is separate from the native adapter. Every demo page shows “演示数据”; demo goal edits remain in memory.

`lib/manual_timer.dart` stores user-created intervals with explicit running and paused segments. The home screen starts an uncategorized interval in one tap; a timestamp persisted at start lets it resume after app suspension or restart without a continuously running background service. Completed segments are split at local-day boundaries for daily/weekly manual charts. A single active timer is allowed. The current implementation uses local SharedPreferences JSON for a small first release; migrate to a transactional local database before relying on long-term personal history. Web demo manual entries are genuine browser-local records and are labeled apart from fixed screen-use samples.

The demo's hourly strips and cross-category baseline bars illustrate the intended reading experience. Their exact data granularity and composition on iOS must be validated inside the Device Activity Report extension before treating these Flutter charts as a production specification. Do not infer waking time, offline work, or a complete day from screen-use data.

## Data rules

- Keep local calendar dates and time-zone boundaries explicit; a day is not assumed to be 24 elapsed hours across time-zone changes.
- Do not add overlapping app durations together to claim unique device screen time without validating the source semantics.
- Never add manual activity durations to device screen time as one total: a person can use a phone during a manually tracked activity. iOS protected report data remains in its extension and is not copied into the timer store.
- Distinguish missing permission, no recorded data, and zero usage.
- A goal consists of selected apps, duration, active state, and reminder preference. A dismissed alert does not silently change the goal.

## Risks to verify on physical devices

1. iOS entitlement and authorization, app selection, report appearance, threshold callback, and notification behavior.
2. Android usage access, daily totals, app labeling, revoked permission, and background-check delay.
3. Rendering and gesture performance on a lower-end supported device.
