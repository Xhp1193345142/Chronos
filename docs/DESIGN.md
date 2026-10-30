# Visual and interaction specification

## Direction

Chronos is a calm instrument panel for time, not a punishment dashboard. Lead with a specific, checkable observation, then show the chart that supports it. The visual hierarchy is: current total with its reference, when usage happened, category comparison, then a user-set goal. Use generous spacing and a small number of strong colors.

## Interface craft

Aim for the clarity and finish of a first-party mobile app while keeping Chronos's own identity. Each screen starts with a quiet context label and one short title. On Today, the largest type belongs to the real or clearly labeled sample total; a compact comparison sits beside that number, followed by one dominant time chart and then the ranked destinations. On Trends, a single summary precedes the seven-day rhythm and daily totals. On Goals, the current goal and its controls have separate, clearly named groups. Do not repeat the same headline inside several equally prominent cards.

Use the platform's system font, tabular figures for large durations, restrained weights, aligned edges and consistent section spacing. Summary and control surfaces use a 20-point corner radius and subtle borders. Data charts sit on the page with a fine top rule instead of being enclosed in repeated cards. Reserve strong color for selected data, status and controls. Theme changes keep chart meaning and layout stable. Interactive chart selection may animate briefly, but follows the platform's reduced-motion preference.

The app icon keeps Chronos's open-clock C mark in lavender on midnight indigo. The selected source image lives at `assets/branding/chronos-icon-source.png`; `tools/generate_icons.py` documents how platform icon sizes are derived. Do not reintroduce the old neon-green mark when updating platform assets.

## Switchable themes

| Theme | Background | Surface | Text | Focus |
| --- | --- | --- | --- | --- |
| 暮光星图 | `#0E1024` | `#1B2040` | `#F5F4FF` | `#AA9BFF` |
| 晨雾纸感 | `#F6F4EE` | `#FFFFFF` | `#1D292B` | `#127B72` |
| 日落脉冲 | `#17131E` | `#292230` | `#FFF8F3` | `#FF967E` |

The appearance picker also offers **跟随系统**: light maps to 晨雾纸感 and dark maps to 暮光星图. The selection is stored locally and applies to the device-data UI and demo UI. The Flutter `ChronosPalette` theme extension owns surface, text, focus, category, usage-intensity and semantic colors; usage data objects never own display colors.

Use `positive` for a factual favorable comparison, `caution` for elevated-but-ordinary usage, and `danger` only for an exceeded goal or destructive action. Color never replaces a numeric label, icon or explicit state text. Each theme has its own ordered usage-intensity scale and stable category-color order.

Use quiet surfaces, subtle separators, and a consistent 8-point spacing scale. Large numbers should use tabular figures where available. Usage intensity is a tonal scale within each theme; category colors are reserved for actual categories, not assigned to ranked apps. Daily bars include a visible average rule. Category comparisons use a colored duration line and a hollow baseline point. Motion should explain a transition or selection; never animate charts simply to decorate them.

## Primary screens

- **Today:** one large screen-time total with a factual comparison and category ring, a tappable 24-hour activity chart when the hourly data is trustworthy, category bars with previous three same weekdays as the baseline, and a goal progress card. When hourly data is unavailable, show a compact explanation and keep the app ranking available.
- **Trends:** a concise seven-day summary, one hourly intensity strip per day, selectable daily totals, a weekly average, and a short factual comparison. The summary uses completed days only when device data is incomplete.
- **Goals:** a short title, selected-app limits, progress, reminder preference, and edit controls grouped by task.

## Interaction and state rules

- Chart labels must include readable values; color alone must never carry meaning.
- Hourly colors encode usage intensity, not app category; the category comparison bars use category colors. A vertical tick is the baseline and must be explained in text.
- Tapping an hour reveals its duration. Tapping a day updates both the selected peak period and daily total. Switching tabs preserves selections.
- Show a clear loading state; denied permission has an explanation and a settings action; no data is distinct from zero usage.
- Sample/demo mode stays labeled on every main screen. Never show demo values as device facts.
- Respect reduced-motion settings and text scaling. Provide semantic labels for chart summaries and controls.

## Performance acceptance

Review release/profile builds on real iOS and Android devices. Scroll, chart selection, and navigation should show no visible stalls. Move usage calculations away from animation frames, render only visible list content, and profile before adding visual effects.
