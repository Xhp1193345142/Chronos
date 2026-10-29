# Visual and interaction specification

## Direction

Chronos is a calm instrument panel for time, not a punishment dashboard. Lead with a specific, checkable observation, then show the chart that supports it. The visual hierarchy is: change from a reference, current total, when usage happened, category comparison, then a user-set goal. Use generous spacing and a small number of strong colors.

## Tokens for the first demo

| Role | Color |
| --- | --- |
| Background | `#0B1020` |
| Surface | `#151C2E` |
| Primary text | `#F6F7FB` |
| Secondary text | `#9BA8BF` |
| Accent / focus | `#A7F070` |
| Social | `#F6B765` |
| Work | `#78B7F7` |
| Other | `#AA94F3` |

Use rounded cards, subtle separators, and a consistent 8-point spacing scale. Large numbers should use tabular figures where available. Motion should explain a transition or selection; never animate charts simply to decorate them.

## Primary screens

- **Today:** a factual headline, total screen time and category ring, a tappable 24-hour activity chart, category bars with previous three same weekdays as the baseline, and a goal progress card.
- **Trends:** seven days ending on the demo's current date, one hourly intensity strip per day, selectable daily totals, a weekly average, and a short factual comparison.
- **Goals:** selected-app limits, progress, reminder preference, and edit controls.

## Interaction and state rules

- Chart labels must include readable values; color alone must never carry meaning.
- Hourly colors encode usage intensity, not app category; the category comparison bars use category colors. A vertical tick is the baseline and must be explained in text.
- Tapping an hour reveals its duration. Tapping a day updates both the selected peak period and daily total. Switching tabs preserves selections.
- Show a clear loading state; denied permission has an explanation and a settings action; no data is distinct from zero usage.
- Sample/demo mode stays labeled on every main screen. Never show demo values as device facts.
- Respect reduced-motion settings and text scaling. Provide semantic labels for chart summaries and controls.

## Performance acceptance

Review release/profile builds on real iOS and Android devices. Scroll, chart selection, and navigation should show no visible stalls. Move usage calculations away from animation frames, render only visible list content, and profile before adding visual effects.
