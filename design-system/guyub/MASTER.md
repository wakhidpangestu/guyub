# Guyub design system

The source of truth for how Guyub looks and moves. Page-specific rules live in `pages/`; a page file overrides this one where they differ.

The brand tokens were chosen by the team and are in `tokens.css`, unchanged. Do not edit colors in Dart: edit `tokens.css`, then mirror the value in `apps/dashboard/lib/ui/tokens.dart`. `test/ui/tokens_test.dart` fails when the two differ.

## Direction

Simple, colorful, and readable on every device. A bento dashboard: a neutral shell, with bright cards for the numbers people act on.

Three references shaped it. They are React components, so they were ported to Flutter rather than installed:

| Reference | What Guyub takes from it |
| --- | --- |
| `app-1` | The shell: sidebar, sticky header, stat row, chart, lists |
| `web3-bento` | The cards: large radius, solid color fills, gauge, segmented bar, mono numbers |
| `draggable-widget-grid` | The grid: an exact tiler, drag to rearrange, touch long press, Alt + arrows |

## Tokens in Flutter

| Need | Use | Avoid |
| --- | --- | --- |
| Any token | `GuyubTokens.of(context)` | Hex values in widgets |
| Material widgets | `Theme.of(context).colorScheme`, built from the tokens in `lib/ui/theme.dart` | `ColorScheme.fromSeed` |
| Spacing | `tokens.sp(4)` (Tailwind's `p-4`) | Unrelated pixel values in new widgets |
| Card fill | `tokens.tone(TileTone.cyan)` | Picking text color by eye |
| Numbers | `tokens.numeric(style)` (mono, tabular) | Proportional digits that jump |

Spacing and fonts differ per theme, as `tokens.css` specifies, so every card must fit in both themes. `test/features/dashboard_test.dart` checks this.

### Where the code departs from the tokens

These are deliberate, and each one is the smallest change that keeps text readable.

| Token | Problem | What the code does |
| --- | --- | --- |
| `--destructive` | 3.6:1 under `--destructive-foreground`, 3.8:1 on white. Below the 4.5:1 for normal text. | Error sentences use a derived shade (`onErrorContainer`). The destructive button still uses the token, so its label is below 4.5:1. **Open for the team to decide.** |
| Dark `--accent-foreground` on `--accent` | 4.16:1 | `tokens.accentText` falls back to `--secondary-foreground`. |
| Dark `--sidebar-accent-foreground` on `--sidebar-accent` | 4.26:1 | `tokens.sidebarAccentText`, same fallback. |
| `--muted-foreground` on `--muted` (light) | 4.42:1 | Pills on `--muted` use `--foreground`. |
| Dark `--font-mono: Consolas` | Proprietary, so it cannot be bundled, and Flutter web's canvas cannot read system fonts. | JetBrains Mono in both themes. |
| Dark `--shadow-*` | Wide and offset. On the near-black page it only shows as a smudge on a bright neighbor. | Cards at rest have no shadow in dark mode. A lifted card has its own shadow. |
| `--letter-spacing` with Plus Jakarta Sans | Small text read as one word, because the font's space is narrow. | Adds 0.12em word spacing in light mode. |

For the Next.js landing page: the `@theme inline` block in `tokens.css` names radius, fonts, and shadows as `--color-*`. Tailwind v4 treats that namespace as colors, so `font-sans` and `rounded-*` will not pick them up. Map them to `--font-*` and `--radius-*` there.

## Typography

| Use | Font |
| --- | --- |
| Interface, light | Plus Jakarta Sans 400, 500, 600, 700 |
| Interface, dark | Public Sans 400, 500, 600, 700 |
| Numbers and short data | JetBrains Mono 400, 500, 600 |

Fonts are bundled in `apps/dashboard/assets/fonts`, so the app makes no font CDN request. Icons are Material outlined, one family at one weight. No emoji as icons.

## Color on cards

- Plain cards use `--card` with a `--border` hairline. Lists and charts are plain, so they stay readable.
- Solid cards use `--chart-1` to `--chart-5` or `--primary`, with a gentle gradient of the same hue.
- Text color on a solid card comes from `tokens.tone()`: near-black or near-white, whichever reads better on both ends of the gradient. A test requires 4.5:1 for primary and secondary text on every tone, in both themes.
- Color never carries meaning alone. Bars have a text line, chart series differ in form (solid and dashed), and statuses have a label.
- Planned features stay neutral and always say `Planned · Mx`. The handbook requires unfinished features to be labelled. Color is for what works.

## Shell

| Width | Navigation |
| --- | --- |
| 960 and up | Permanent sidebar, 256 wide, collapses to 72 with icons and tooltips |
| Below 960 | Drawer, opened from the header menu button |

- Header: 64 high, with the page title on the left and the theme toggle and account menu on the right.
- Sub-pages show a back button, which follows the router's page stack.
- Pages switch without a transition, so the sidebar appears to stay in place.
- Gutters are `sp(4)` below 640 and `sp(6)` from 640.

## Components

All in `apps/dashboard/lib/ui/dashboard/`.

| Component | File | Notes |
| --- | --- | --- |
| `DraggableWidgetGrid` | `draggable_widget_grid.dart` | Stack of animated cards |
| Layout logic | `grid_layout.dart` | Pure Dart, unit tested |
| `DashboardGrid`, `DashboardCard` | `dashboard_grid.dart` | Saves the order, has the Arrange dialog |
| `Tile`, `HeroTile`, `StatTile`, `PlannedTile` | `tiles.dart` | Card surfaces |
| `EventRow`, `FitList`, `SeatsBar`, `Gauge`, `AttendanceChart` | `tiles.dart` | Card content |
| Card numbers | `attendance_series.dart` | Pure Dart, unit tested |

Card rules:

- Cards have a fixed height. Content must fit or truncate, never scroll inside a card, because a nested scroll would fight the drag.
- Long lists use `FitList`, which shows as many rows as fit, plus a "View all" link.
- Every number comes from real data. If there is no data, the card says what to do next. Do not ship sample numbers.

## Interaction

| Input | Rearrange a card |
| --- | --- |
| Mouse | Drag after a small movement |
| Touch, stylus | Press and hold 350 ms, then drag. A swipe still scrolls the page. |
| Keyboard | Focus a card, hold Alt, and press an arrow key |
| One tap (WCAG 2.5.7) | The Arrange dialog has Move up and Move down buttons, and Reset order |
| Screen reader | "Move earlier" and "Move later" custom actions |

- The order is saved per person on the device, in `shared_preferences`. It is not synced between devices.
- Near the top or bottom of the viewport, a drag scrolls the page.
- Motion: cards move in 380 ms with a slight overshoot, and lift in 180 ms. `MediaQuery.disableAnimations` makes all of it instant.
- Touch targets are at least 44 high.

## Before shipping UI

- `flutter test` covers every dashboard at six screen sizes in both themes. A layout overflow fails it.
- Look at the real result as well. Overflow tests did not catch a progress bar with zero height or misplaced header buttons. A browser screenshot did.
