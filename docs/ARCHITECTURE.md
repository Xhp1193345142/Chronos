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

Android's `UsageReader` runs behind the `chronos/native` method channel and returns dated snapshots with explicit `available`, `reason` and `source` fields. It queries recent events once per read, using preceding events to establish boundary state. `UsageTimeline` accounts for activity class transitions, pause/stop, lock/unlock, screen off and device shutdown/startup. An activity resumed before the unlock event remains pending and starts counting at unlock. Intervals clip to local dates; a conflict extending across midnight invalidates the affected period. Events are memory-only, not copied into a history store. Public APIs do not expose activity instance IDs; multi-resume/conflicting streams remain conservative and require more device validation.

If event coverage does not reach the beginning of a date, fallback daily aggregates must start exactly at local midnight, end within the requested window and stay within elapsed-time bounds. Android can expand queries to its own interval buckets: an OEM bucket beginning at 11:52 is not accepted as a natural-day total. Missing/unreliable dates never become zero; a covered event interval with no foreground activity can be genuine zero. Today and goal checks use the same accounting rules. Per-app labels/categories are cached only within one snapshot. Rankings omit sub-minute apps; daily/goal totals sum underlying intervals before rounding down to minutes. Hourly values are separately rounded, so displayed minute sums can differ. Different sources do not contribute to one comparative fact or baseline.

`GoalStore` keeps goals and insight preferences in private SharedPreferences. Goal and check-result writes commit synchronously; corrupt source goals remain intact and cannot be replaced by an implicit empty list. `GoalChecker` serializes foreground and background checks, revalidates the goal/date before posting and records the outcome. Permission/channel denial and missing usage do not mark a reminder sent. Notifications use a goal-specific tag and PendingIntent, a monochrome icon and private lock-screen visibility. A posted notification is marked once per local date; this means accepted by Android, not proof of audible delivery under DND.

`GoalCheckJobService` uses inexact periodic JobScheduler checks and cancellation tokens. Existing jobs are retained rather than resetting their period on every app entry. Startup and boot/package-replacement/time-change receivers restore scheduling when goals are enabled. The Flutter goal page shows scheduling/check results, supports a real-data immediate check and links to system notification settings. Cold and warm notification intents route to real goals even from journal/demo mode without rewriting the saved mode preference. The Flutter live pages never replace a permission or loading failure with demo values.

`lib/demo_data.dart` still provides fixed, deterministic data for Web previews and the optional on-device demo. It is separate from the native adapter. Every demo page shows “演示数据”; demo goal edits remain in memory.

`lib/manual_timer.dart` stores user-created intervals with explicit running and paused segments. The home screen starts an uncategorized interval in one tap; a timestamp persisted at start lets it resume after app suspension or restart without a continuously running background service. Completed segments are split at local-day boundaries for daily/weekly manual charts. A single active timer is allowed. Mutations are serialized; validated state is published only after persistence succeeds. Clock rollback, overlapping intervals and malformed backups cannot create a journal that fails its next load.

`lib/storage/` isolates persistence. Android and iOS use SQLite transactions with a unique active-timer index and incremental row writes. The first load validates the legacy preference payload before committing migration; a metadata marker makes the database authoritative and prevents stale preferences from resurrecting deleted records. Legacy cleanup happens after commit. Failed loads retain source data and disable mutations other than explicitly confirmed deletion. Web and non-mobile previews retain SharedPreferences. Native iOS behavior still requires an actual build and device test.

User-selected JSON backup and CSV export use the OS file picker. JSON is a versioned manual-record snapshot; a running timer is completed only in the exported snapshot. Restore validates size, category, interval order, uniqueness and overlap; identical IDs skip, conflicts reject the entire merge. CSV is read-only interchange with escaped cells and formula neutralization. Neither format contains device usage or goals; files are plain text, and the user may choose a cloud file provider. No app server is involved. Android opts out of OS backup/transfer; iOS system backup remains controlled by platform/device settings.

iOS starts in the independent journal, while Android can persist a journal-only choice and reconnect to device usage through settings. This is a UI choice, not an implicit change to saved goals: enabled Android goals retain their original background checks; the mode/settings copy explains this. This route does not call a missing iOS native screen-time channel. Web demo manual entries remain genuine browser-local records, labeled apart from fixed screen-use samples.

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
