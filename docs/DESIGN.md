# Visual and interaction specification

## Direction

Chronos is a calm instrument panel for time, not a punishment dashboard. The visual hierarchy is: current total, direction of change, distribution, then a suggested action. Use generous spacing and a small number of strong colors.

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

- **Today:** total screen time, a 24-hour activity strip, top categories, and a goal progress card.
- **Trends:** a seven-day chart, average, and a short factual comparison.
- **Goals:** selected-app limits, progress, reminder preference, and edit controls.

## Interaction and state rules

- Chart labels must include readable values; color alone must never carry meaning.
- Tapping a chart segment reveals its label and duration. Switching day/week preserves the user's place.
- Show a clear loading state; denied permission has an explanation and a settings action; no data is distinct from zero usage.
- Sample/demo mode stays labeled on every main screen. Never show demo values as device facts.
- Respect reduced-motion settings and text scaling. Provide semantic labels for chart summaries and controls.

## Performance acceptance

Review release/profile builds on real iOS and Android devices. Scroll, chart selection, and navigation should show no visible stalls. Move usage calculations away from animation frames, render only visible list content, and profile before adding visual effects.
