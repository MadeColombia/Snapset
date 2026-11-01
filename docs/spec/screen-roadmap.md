# Screen-building roadmap

2026-11-01. How to go from the approved brand to built SwiftUI screens, in order. Fits [plan.md](plan.md), [todo.md](todo.md), ADR-001 (native SwiftUI, `SnapsetUI` package, GRDB) and ADR-002 (min iOS 18). Visual page: [Snapset Roadmap](https://claude.ai/artifact/AjJ5hvWknPu7U6oicNHDQP). What each screen must look like: [design/flows.md](../design/flows.md) revision 6 and [design/screen-audit.md](../design/screen-audit.md).

## The idea

Build the look once (tokens), then the pieces (components), then the screens, starting with the two screens used dozens of times per workout (S12 Workout session and S13 Set confirm). Everything visual lives in `Packages/SnapsetUI` with SwiftUI previews in dark, light and the largest text size, so each screen is checked against the brand before it is wired to data.

**Decided 2026-11-01:** do D3's high-fidelity screens as SwiftUI previews with mock data instead of a Figma file. The previews become the real screens, which saves a solo developer drawing everything twice, and UI work can start now while the Task 1 vision spike runs, because `SnapsetUI` does not need the data model. Only the photo screens would be wasted if the spike says "stop". Figma stays useful for App Store art later.

## Update 2026-11-01 (evening): the app already exists

The repo already had 10 working screens. PR MadeColombia/Snapset#2 restyled all of them with SnapsetUI (M0 plus a brand pass on Workout, Set confirm, running bar, Routines, Routine editor, Progress, Exercise detail, Onboarding, Settings, Live Activity). So M1 to M3 below become **upgrades of existing screens**, not new builds. Next, in order:

1. Workout session as the step-by-step roadmap (S12, S34) with the rest timer, in its own PR
2. Progression reasons with real numbers ("You got 12 on every set. Add 2.5 kg.") and new-best detection, which unlock the S16 summary and its one celebration
3. Then photo logging (M6) once the Task 1 spike says go; Set confirm already has the photo states

## Milestones

| # | Milestone | Screens and components | Plan tasks | Needs | Done when |
|---|---|---|---|---|---|
| M0 | **Tokens** | `design/tokens.md`; `SnapsetUI/Theme`: colour assets (dark and light), type styles, hero number (`@ScaledMetric`, rounded, monospaced digits), spacing, corner radii, motion presets, haptics | D2 | Brand guide (approved) | Contrast table passes WCAG AA for every pair; you approve S12 and S13 drawn with the tokens (D2 verification) |
| M1 | **Component kit** | Primary button (orange and neutral), hero number stepper, set row, status badge (up, hold, lighter), confidence badge, coach card (S60), suggestion line (S62), banner (Amber, Sky), Undo toast, chip, routine card, time bar, roadmap step, demo thumbnail (placeholder art), rest timer, heatmap | D2 | M0 | Every component has previews in dark, light and AX5 text; tap targets 44 pt, logging controls 60 pt |
| M2 | **Core loop prototype** | S13 Set confirm (all states), S12 Workout session, S34 Routine roadmap, S16 Session summary, S20 and S21 as mock screens | D3 | M1 | Three people who lift log a set by hand and by (mock) photo without help; notes in `design/test-notes.md` |
| | **Checkpoint: Design** | | | | You approve the screens |
| M3 | **Tracker screens** | Tab shell, S10 (today card only), S11, S30, S31, S35, S14, S12 and S13 on real data, S16, S40 to S43, S36 (placeholder demos) | 2, 3, 4, 5 | M2, Task 1 go | Full workout logged and reviewed on your phone in airplane mode (Tracker checkpoint) |
| M4 | **First run and account** | S01, S71 to S75, S05, S06, S02, S03, S07, S09 (library match), S50, S52 Reminders | 17, 9, 16 | M3 | New install to first workout with no dead ends; Skip setup in 1 tap |
| M5 | **Coaching and Home** | Live badges on S12, S62 lines, S10 full (heatmap, look back, back-after-break), S32, S33 with First month; Pro: S60 cards, S08, S61 | 10, 11, 18, 15 | M3, M4 | Badge colours and copy match flows F9; free app shows no empty or locked slots |
| M6 | **Photo and Pro** | S20, S21, S22 real camera, S13 photo variants, S23 Paywall | 6, 7, 8, 12, 13 | M3, Task 1 go | Photo logging in 3 taps or fewer after the shutter, in a real gym |
| M7 | **Gym extras** | S36 with real demos, S37, S38, gym mode, Live Activity, widgets, S51, App Intents | 19, 20, 21, 22, 23 | M3 | Each extra checked in dark, light, AX5 and Reduce Motion |
| M8 | **Release polish** | Light-mode and VoiceOver pass on every screen, App Store screenshots in the brand style ("Know what to lift next.", one big number) | 14 | M4 to M7 | Ready for TestFlight |

M4 to M7 can overlap once M3 is done. M6 waits on the Task 1 go decision; nothing else after M2 does except Task 2's data model.

## Order inside M1 and M2

1. Hero number stepper and primary button (they make S13)
2. Set row, Undo toast, status badge, rest timer (they make S12)
3. Roadmap step and demo thumbnail (S34, S12)
4. Coach card, suggestion line, banner (every state of S12, S13, S16)
5. Routine card, time bar, chip (Routines tab)
6. Heatmap last (only Home and the large widget use it)

## How each screen is checked

- Previews: dark, light, `.accessibility5` Dynamic Type, and Reduce Motion where it moves.
- The brand checklist (brand guide section 10): one orange thing, number biggest, no jargon, no red, colour with an icon or word, sentence case.
- Build and tests: `xcodebuild test -scheme Snapset -destination 'platform=iOS Simulator,name=iPhone 17'` (from todo.md).
- Accessibility Inspector audit in Xcode on the simulator for contrast and labels.
