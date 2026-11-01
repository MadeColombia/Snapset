# Snapset design tokens

Task D2, milestone M0 of [screen-roadmap.md](../tasks/screen-roadmap.md). Draft 2026-11-01, not approved yet. Every value comes from the approved [brand guide](brand/brand-guide.md); this page gives each one a name so the Swift theme (`Packages/SnapsetUI/Theme`) and every screen use the same words. If a value has to change, change the brand guide first.

Names are semantic (what the token is *for*), so a screen never says "orange", it says `accent`. In Swift each colour token becomes a colour set in the `SnapsetUI` asset catalog with an Any and a Dark appearance, exposed as `Color.snap.<name>`.

## 1. Colour

| Token | Dark | Light | Use |
|---|---|---|---|
| `background` | `#14171B` Graphite | `#F7F5F0` Chalk paper | Screen background |
| `surface` | `#1E2227` Iron | `#FFFFFF` | Cards, sheets, coach card |
| `surfaceRaised` | `#2A2F36` Iron raised | `#ECE8DF` | Steppers, chips, camera button, current roadmap step, neutral pressed |
| `line` | `#3A3F47` Iron line | `#D9D4C9` | Dividers, outlines, roadmap line |
| `textPrimary` | `#F3F0E8` Chalk | `#14171B` | Body text, hero numbers, neutral primary button fill |
| `textSecondary` | `#A9ADB4` Chalk muted | `#5B616B` | Secondary text, suggestion lines, "Last time" |
| `accent` | `#FF5A2C` Pin orange | `#C9400F` | The one orange thing: primary button or coach card border and label |
| `onAccent` | `#14171B` | `#FFFFFF` | Text and icons on `accent` |
| `statusUp` | `#6FCF97` Sage | `#1F7A4D` | Going up, new best, saved, heatmap |
| `statusHold` | `#7DB3E8` Sky | `#2F64A8` | Hold, information, offline notes |
| `statusDown` | `#F2B84B` Amber | `#8A5A00` | A bit lighter, needs a look, couldn't read, over time |
| `destructive` | system red | system red | Only iOS destructive buttons (Delete account, Delete routine) |

Heatmap steps (4 levels, more sets = stronger): `statusUp` at 25%, 50%, 75% and 100% opacity on `surface`; empty days are `surfaceRaised`; today has a 1.5 pt `textPrimary` outline.

### Contrast (WCAG 2.1, computed 2026-11-01)

| Text colour | on `background` | on `surface` | on `surfaceRaised` |
|---|---|---|---|
| Dark `textPrimary` | 15.8 | 14.0 | 11.8 |
| Dark `textSecondary` | 8.0 | 7.1 | 6.0 |
| Dark `accent` | 5.8 | 5.1 | 4.3 (large only) |
| Dark `statusUp` / `statusHold` / `statusDown` | 9.5 / 8.1 / 10.0 | 8.4 / 7.2 / 8.9 | 7.1 / 6.1 / 7.5 |
| Light `textPrimary` | 16.5 | 18.0 | 14.7 |
| Light `textSecondary` | 5.7 | 6.2 | 5.1 |
| Light `accent` | 4.6 | 5.0 | 4.1 (large only) |
| Light `statusUp` / `statusHold` / `statusDown` | 4.9 / 5.5 / 5.4 | 5.3 / 6.0 / 5.9 | 4.3 (large only) / 4.9 / 4.8 |

`onAccent` on `accent`: 5.8 dark, 5.0 light. Everything passes AA (4.5) for body text except the three cells marked "large only", which are allowed for text 18 pt and larger and for icons. Rule for code: never put `accent` or light `statusUp` body text on `surfaceRaised`.

### Colour rules

1. **One `accent` per screen.** If a coach card is on screen, the primary button uses the neutral style.
2. **Status colour never alone.** Always with its SF Symbol and a word: `arrow.up` / `checkmark` (up), `equal` / `info.circle` (hold), `arrow.down` / `exclamationmark.circle` (down).
3. **No red** outside `destructive`.

## 2. Type

SF Pro (system) for text, SF Pro Rounded with monospaced digits for numbers. Only Dynamic Type styles, never fixed sizes, except the hero number, which scales with `@ScaledMetric`.

| Token | SwiftUI | Weight | Use |
|---|---|---|---|
| `heroNumber` | 64 pt, `design: .rounded`, `.monospacedDigit()`, scaled relative to `.largeTitle` | Semibold | Weight and reps on S12 and S13, gym mode (larger), Live Activity |
| `heroUnit` | `.title2`, rounded | Regular | "kg", "reps" next to a hero number |
| `numberMedium` | `.title`, rounded, monospaced digits | Semibold | Rest timer, routine time, summary numbers |
| `screenTitle` | `.largeTitle` | Bold | Today, Routines, History |
| `sectionTitle` | `.title3` | Semibold | Exercise name, card titles |
| `body` | `.body` | Regular | Reasons, coach card text |
| `secondary` | `.subheadline` | Regular, `textSecondary` | "Last time", suggestion lines, source label |
| `label` | `.footnote` | Semibold | Chips, badges, "Coach" label (changed from Medium 2026-11-01 to keep two weights per screen) |

At most two weights per screen (Regular plus Semibold or Bold). Bold only for titles and numbers.

## 3. Spacing, size and shape

| Token | Value | Use |
|---|---|---|
| `space.xs` | 4 | Icon to label |
| `space.s` | 8 | Inside chips and badges |
| `space.m` | 12 | Between rows in a card |
| `space.l` | 16 | Card padding, screen side margin |
| `space.xl` | 24 | Between cards and sections |
| `space.xxl` | 32 | Above the hero number, around the primary action area |
| `tap.min` | 44 | Every tappable thing |
| `tap.logging` | 60 | *Log set*, *Save set*, steppers, camera button |
| `tap.gym` | 80 | The same controls in gym mode |
| `radius.card` | 16 | Cards, sheets content |
| `radius.control` | 14 | Buttons, steppers |
| `radius.chip` | 8 | Chips, badges |
| `border.coach` | 1 pt `accent` | Coach card only |
| `border.hairline` | 1 pt `line` | Card outlines in light mode, dividers |

Spacing scales with Dynamic Type through `@ScaledMetric` for `space.l` and larger, so big text keeps its breathing room.

## 4. Motion and haptics

| Token | Value | Use |
|---|---|---|
| `motion.quick` | `.snappy` spring, about 0.25 s, no overshoot | Badges, chips, toasts |
| `motion.standard` | `.smooth` spring, about 0.35 s | Sheets, step expand and collapse, set row settling in |
| `motion.reduced` | `.easeInOut(duration: 0.2)` opacity only | Any of the above when Reduce Motion is on |
| `haptic.saved` | light impact | Set saved |
| `haptic.best` | success | New best (the only celebration; plus a Sage glow on the number) |
| `haptic.step` | selection | Stepper changes |

In SwiftUI these map to `.animation(.snappy)`, `.animation(.smooth)` and `.sensoryFeedback(...)`. Verify the exact presets and `sensoryFeedback` options in Apple's current docs when writing the theme (`sensoryFeedback` needs iOS 17, which is below our iOS 18 minimum).

## 5. Component tokens

The component kit (M1) uses only the tokens above. The visual rules each one must follow:

| Component | Fill | Text | Notes |
|---|---|---|---|
| Primary button | `accent` | `onAccent`, `.headline` | `tap.logging` tall, full width at the bottom |
| Neutral primary button | `textPrimary` | `background` | Used when a coach card holds the accent |
| Secondary button | `surfaceRaised` | `textPrimary` | Same height as the primary next to it (paywall, Not now) |
| Hero number stepper | `surfaceRaised` minus and plus, 60 pt | `heroNumber` | Number tap opens the number pad (last resort) |
| Set row | `surface` | `body` rounded digits | "W" mark for warm-up in `textSecondary` |
| Status badge | none | status colour + symbol + word, `label` | Up, hold, a bit lighter |
| Confidence badge | none | `statusUp` "Read from photo" or `statusDown` "Not sure about this one" | Low confidence also outlines the number in `statusDown` |
| Coach card | `surface`, `border.coach` | "Coach" in `accent` `label`, body in `textPrimary` | Actions are text buttons in `textPrimary` |
| Suggestion line | none | `info.circle` + `secondary` | At most one text action |
| Banner | `surface` | status symbol + `body` | Amber for problems, Sky for information |
| Undo toast | `surfaceRaised` | `body` + *Undo* | 5 s, `motion.quick` |
| Roadmap step | `surface`; current step `surfaceRaised` with a 2 pt `textPrimary` leading line | Start time in `numberMedium`-style digits | Done steps collapse with a `statusUp` check |
| Time bar | track `surfaceRaised` | fill `statusUp` when it fits, `statusDown` when over | Always with the minutes as text |

## 6. Approval

D2 verification asks you to approve the direction on two sample screens before the rest are drawn. With the SwiftUI previews decision, those two are **S13 Set confirm** and **S12 Workout session**, built as previews from these tokens in the `SnapsetUI` package.
