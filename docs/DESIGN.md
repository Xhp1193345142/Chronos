# Visual and interaction specification

## Direction

Chronos is a calm instrument panel for time, not a punishment dashboard. Lead with a one-tap manual timer, then show specific, checkable observations and supporting charts. Manual time and phone usage are separate measures. Use generous spacing and a small number of strong colors.

## Interface craft

Aim for the clarity and finish of a first-party mobile app while keeping Chronos's own identity. Each screen starts with a quiet context label and one short title. On Today, a prominent timer starts immediately without a category prompt; compact quick actions start common activity categories in one tap. The local activity ledger follows, then device screen use or clearly labeled sample charts. A persistent dock action starts the timer from other tabs; while active it opens its controls. On Trends, manual activity and screen-use rhythms have distinct headings and totals. On Goals, the current goal and its controls have separate, clearly named groups. Do not repeat the same headline inside several equally prominent cards.

Use the platform's system font, tabular figures for large durations, restrained weights, aligned edges and consistent section spacing. The top bar is a quiet wordmark with small source or settings controls. The Today heading has a real date above it, not another copy of “today.” The timer is the main control surface: a fine clock dial, one clear start action, and compact category shortcuts. Avoid decorative gradients and repeated accent-colored badges. Primary buttons use rounded rectangles; the persistent timer action is a circle. Keep only a few summary surfaces, with subtle borders and no competing headline cards. Data charts sit on the page with a fine top rule instead of being enclosed in repeated cards. Reserve strong color for selected data, status and controls. Theme changes keep chart meaning and layout stable. Interactive chart selection may animate briefly, but follows the platform's reduced-motion preference.

The app icon keeps Chronos's open-clock C mark in lavender on midnight indigo. The selected source image lives at `assets/branding/chronos-icon-source.png`; `tools/generate_icons.py` documents how platform icon sizes are derived. Do not reintroduce the old neon-green mark when updating platform assets.

## Switchable themes

| Theme | Background | Surface | Text | Focus |
| --- | --- | --- | --- | --- |
| 暮光星图 | `#0E1024` | `#1B2040` | `#F5F4FF` | `#AA9BFF` |
| 晨雾纸感 | `#F6F4EE` | `#FFFFFF` | `#1D292B` | `#127B72` |
| 日落脉冲 | `#17131E` | `#292230` | `#FFF8F3` | `#FF967E` |

The appearance picker also offers **跟随系统**: light maps to 晨雾纸感 and dark maps to 暮光星图. The selection is stored locally and applies to the device-data UI and demo UI. The Flutter `ChronosPalette` theme extension owns surface, text, focus, category, usage-intensity and semantic colors; usage data objects never own display colors.

On Trends, show the visual rhythm before a derived comparison number. A manual history shorter than one minute uses compact seven-day marks with exact seconds; longer history uses duration bars. An almost empty full-height chart gives the wrong visual weight to sparse data.

Use `positive` for a factual favorable comparison, `caution` for elevated-but-ordinary usage, and `danger` only for an exceeded goal or destructive action. Color never replaces a numeric label, icon or explicit state text. Each theme has its own ordered usage-intensity scale and stable category-color order.

Use quiet surfaces, subtle separators, and a consistent 8-point spacing scale. Large numbers should use tabular figures where available. Usage intensity is a tonal scale within each theme; category colors are reserved for actual categories, not assigned to ranked apps. The demo screen-time summary uses one proportional category strip with a labeled leading category instead of an additional donut. Daily bars include a visible average rule. Category comparisons use a colored duration line and a hollow baseline point. Motion should explain a transition or selection; never animate charts simply to decorate them.

## Primary screens

- **Today:** one-tap start, active elapsed time with pause and stop, a local activity strip and editable entries. Screen-time totals, hourly charts, category comparisons and goals follow as separate data.
- **Trends:** a seven-day manual-record chart followed by separately labeled screen-use trends. The screen summary uses completed days only when device data is incomplete.
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
