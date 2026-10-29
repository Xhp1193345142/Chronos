# Product brief

For screen-by-screen behavior, rule definitions, platform fallbacks, and acceptance scenarios, see [the detailed functional design](FUNCTIONAL_SPEC.md).

## Purpose

Chronos helps people understand where their screen time goes and act on goals they choose. Its value is a clear visual account of time and reminders the user can adjust.

## First real release

1. Explain and request access to system app-usage data.
2. Show daily and weekly usage with a clear total, app or category breakdown, and comparison to a previous period where supported.
3. Let the user select apps, set a daily combined time limit, and adjust or pause the reminder.
4. Display permission, loading, empty, and unavailable states honestly.

## Demo scope

The first demo is a polished Flutter interface using fixed sample data. It demonstrates the home dashboard, a 24-hour screen-use rhythm, category comparisons against sample baselines, seven-day rhythms, goals, and chart interaction. The demo's seven days end on Thursday, October 29. It does not read real screen time, trigger a system notification, use AI, or upload data.

## Later possibilities

- Native iOS and Android data adapters and threshold monitoring.
- Optional weekly explanations based only on information the platform permits the app to use.
- Optional account sync after local-first behavior is proven.

## Non-goals for now

Health or sleep diagnosis, automatic behavioral judgment, forced app blocking, hidden monitoring, and cloud processing of raw device activity.

## Acceptance for the demo

- A user can identify today's total, the largest time category, the busiest three-hour period, and how usage compares with a baseline without reading a paragraph.
- A user can tap an hour or day to inspect the chart, compare the last seven days, and adjust the sample goal.
- Sample data is visibly labeled. UI remains usable on narrow phones and with larger text.
