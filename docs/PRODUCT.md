# Product brief

For screen-by-screen behavior, rule definitions, platform fallbacks, and acceptance scenarios, see [the detailed functional design](FUNCTIONAL_SPEC.md).

## Purpose

Chronos helps people understand where their time goes. A one-tap manual timer records offline activities; platform screen-time reports show phone use as a separate source. Its value is a clear visual account of time and reminders the user can adjust.

## First real release

1. Put one-tap manual timing on the first screen, independent of screen-time permission; allow pause, resume, stop, category, notes, backfill, edit, delete, and local recovery.
2. Explain and request access to system app-usage data separately.
3. Show daily and weekly manual records and screen usage as distinct measures; never add overlapping durations into one total.
4. Let the user select apps, set a daily combined time limit, and adjust or pause the reminder.
5. Display permission, loading, empty, and unavailable states honestly.

## Demo scope

The Web demo keeps fixed, labeled screen-use samples ending Thursday, October 29. Manual timer entries are real local browser records, clearly labeled separately. The demo does not read real screen time, trigger a system notification, use AI, or upload data.

## Later possibilities

- Native iOS and Android data adapters and threshold monitoring.
- Optional weekly explanations based only on information the platform permits the app to use.
- Optional account sync after local-first behavior is proven.

## Non-goals for now

Health or sleep diagnosis, automatic behavioral judgment, forced app blocking, hidden monitoring, and cloud processing of raw device activity.

## Acceptance for the demo

- A user can identify today's total, the largest time category, the busiest three-hour period, and how usage compares with a baseline without reading a paragraph.
- A user can open the app and start a manual timer with one tap, even before granting device-usage access.
- A user can tap an hour or day to inspect the chart, compare the last seven days, and adjust the sample goal.
- Sample data is visibly labeled. UI remains usable on narrow phones and with larger text.
