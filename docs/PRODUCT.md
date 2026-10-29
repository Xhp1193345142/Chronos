# Product brief

## Purpose

Chronos helps people understand where their screen time goes and act on goals they choose. Its value is a clear visual account of time and reminders the user can adjust.

## First real release

1. Explain and request access to system app-usage data.
2. Show daily and weekly usage with a clear total, app or category breakdown, and comparison to a previous period where supported.
3. Let the user select apps, set a daily combined time limit, and adjust or pause the reminder.
4. Display permission, loading, empty, and unavailable states honestly.

## Demo scope

The first demo is a polished Flutter interface using fixed sample data. It demonstrates the home dashboard, time distribution, weekly trend, goals, and interaction. It does not read real screen time, trigger a system notification, use AI, or upload data.

## Later possibilities

- Native iOS and Android data adapters and threshold monitoring.
- Optional weekly explanations based only on information the platform permits the app to use.
- Optional account sync after local-first behavior is proven.

## Non-goals for now

Health or sleep diagnosis, automatic behavioral judgment, forced app blocking, hidden monitoring, and cloud processing of raw device activity.

## Acceptance for the demo

- A user can identify today's total, the largest time category, and how usage changed over the week without reading a paragraph.
- A user can switch between day and week, inspect the chart, and adjust the sample goal.
- Sample data is visibly labeled. UI remains usable on narrow phones and with larger text.
