# Technical architecture

## Chosen stack

- Flutter/Dart for shared navigation, design system, settings, and UI that can use shared data.
- Swift for Family Controls, Device Activity monitoring, and the iOS Device Activity Report extension. Apple's report extension renders its own SwiftUI content in a protected sandbox.
- Kotlin for Android UsageStatsManager integration and background goal checks.
- Local storage for goals, preferences, and permissible summaries. No backend in the first release.

## Boundaries

The Flutter domain layer describes goals and display state. A platform capability layer reports whether usage access is available, supports app selection, configures threshold monitoring, and presents a report. It does **not** promise that both platforms return identical raw usage records.

On iOS, the user selects apps through FamilyActivityPicker; Device Activity monitors thresholds; DeviceActivityReport renders usage charts within its extension. Do not copy sensitive report data into Flutter or send it to a server. The distribution entitlement must be approved before release.

On Android, UsageStatsManager reads permitted app statistics after the user enables usage access. Background checks may be delayed by operating-system scheduling; reminder copy must not imply exact-to-the-minute triggering.

## Demo implementation

`lib/demo_data.dart` provides fixed, deterministic data. It is deliberately separate from future native adapters. The UI shows a persistent “演示数据” label. Goal edits are in-memory for this first visual demo.

The demo's hourly strips and cross-category baseline bars illustrate the intended reading experience. Their exact data granularity and composition on iOS must be validated inside the Device Activity Report extension before treating these Flutter charts as a production specification. Do not infer waking time, offline work, or a complete day from screen-use data.

## Data rules

- Keep local calendar dates and time-zone boundaries explicit; a day is not assumed to be 24 elapsed hours across time-zone changes.
- Do not add overlapping app durations together to claim unique device screen time without validating the source semantics.
- Distinguish missing permission, no recorded data, and zero usage.
- A goal consists of selected apps, duration, active state, and reminder preference. A dismissed alert does not silently change the goal.

## Risks to verify on physical devices

1. iOS entitlement and authorization, app selection, report appearance, threshold callback, and notification behavior.
2. Android usage access, daily totals, app labeling, revoked permission, and background-check delay.
3. Rendering and gesture performance on a lower-end supported device.
