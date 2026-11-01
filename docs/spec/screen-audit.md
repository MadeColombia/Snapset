# Screen audit: D1 flows against the approved brand

2026-11-01. Every screen in [flows.md](flows.md) checked against the approved [brand guide](brand/brand-guide.md) (2026-10-31) and the [brand board](https://claude.ai/artifact/MTipQFgxkuv9TK4Ka71q37). The copy and behaviour changes below have been applied to flows.md (revision 6). The pre-brand version is kept in [archive/flows-v1-2026-10-12.md](archive/flows-v1-2026-10-12.md).

How to read the "Change" column:

| Level | Meaning |
|---|---|
| **Big** | The screen's content or structure changes, not just its look |
| **Copy** | Words change; layout stays |
| **Visual** | Only the shared patterns below apply (colour, type, components) |

## 1. Patterns that apply to every screen

These come straight from the brand guide. They are the "new design pattern": once the components follow them, most screens are already updated.

| Pattern | Rule | Where it bites in D1 |
|---|---|---|
| **One orange thing** | Pin orange goes on the primary button *or* the coach card, never both | S09, S10, S12, S16, S30, S31 carry a coach card next to a primary button. When the coach card is present, the primary button switches to the **neutral primary** (Chalk fill, Graphite text). Without a coach card, the primary button is orange |
| **No red** | Warnings, low confidence, failed saves and "over time" are Amber with an icon and a next step. Only iOS destructive buttons (Delete account, Delete routine) stay system red | S13 save failed, S13 "Check this", S31 over budget, S71 weak password, S73 wrong details, S23 purchase failed, S08 failed |
| **Status = colour + icon + word** | Up: Sage `arrow.up`. Hold: Sky `equal`. Lighter: Amber `arrow.down`. Saved or new best: Sage `checkmark` | Up, down and hold badges (S12, S16, S34), confidence badge (S13), sync status (S50) |
| **Hero number** | Weight and reps in SF Pro Rounded Semibold, monospaced digits, 64 pt scaled with `@ScaledMetric`. The biggest thing on screen | S12 current step target, S13 weight and reps, LA, widgets, gym mode |
| **Number first, reason second** | Every target is a number, then one plain line on why | S12 target line, badges, S16 "next time" list, S34 strength steps |
| **No jargon** | No 1RM, e1RM, volume, PR, load. Say "the most you can lift once", "best", "sets" | S10 progress tiles, S16 summary, S42, S43 |
| **No guilt, no streaks** | Never count missed days or skipped sessions; no "longest run" | S10 heatmap numbers, S10 back-after-break card, S16 coach insight, S61 trigger |
| **Coach is a calm card** | Iron card, 1 pt Pin orange border, "Coach" label in Pin orange (5.1:1 on Iron, passes), body in Chalk, actions as text buttons | S60 everywhere |
| **Free suggestion line stays grey** | `info.circle` in Chalk muted, one line of `.subheadline`, at most one text action | S62 everywhere |
| **Calm motion** | `.smooth` or `.snappy` springs, 0.2 to 0.35 s, no bounce. Saving a set: light haptic and the row settles in. New best: Sage glow plus one success haptic, no confetti | S13 save, S12 set rows, S16 new best |
| **Sentence case, no em dashes, one "!" max** | Only real wins get "!" | All copy (several "−" and "x" fixed to "×" and plain words) |
| **Demo figure style** | Flat Iron-grey figure on Graphite, working muscle in Pin orange, no face | S36 and every thumbnail. On a screen that shows a playing demo with the orange muscle, the primary button goes neutral (one orange thing) |

## 2. Screen by screen

### Account (F0)

| ID | Screen | Change | What changes |
|---|---|---|---|
| S01 | Welcome | **Big** | Gains the app icon, the word mark and the tagline *Know what to lift next.* No orange button: Apple's and Google's standard buttons lead, *Continue with email* is neutral. Failed message is calm and says what to do |
| S71 | Create account | Copy | Weak password turns Amber with `exclamationmark.circle`, not red. Offline copy kept |
| S72 | Check your email | Visual | Unverified banner on S10 uses Sky `info.circle`, not a warning |
| S73 | Log in | Copy | Wrong details and too many tries in Amber |
| S74 | Reset password | Visual | |
| S75 | Account | Visual | *Delete account* keeps system red (the one allowed exception) |

### Onboarding (F1)

| ID | Screen | Change | What changes |
|---|---|---|---|
| S05 | Connect Apple Health | Copy | Opens with the welcoming tone line: "Let's set up your first week. You can skip any question." |
| S06 | About you | Copy | Body weight gets its reason ("Used to suggest starting weights and for Apple Health"), never body talk |
| S02 | Goal | Copy | Each card gets one plain line, reps second: "Build muscle · Get bigger and stronger · 6 to 12 reps" |
| S03 | How you train | **Big** | Level chips reworded for beginners and **Beginner is preselected**: "New to the gym", "Some experience", "Experienced" (stored as beginner, intermediate, advanced) |
| S07 | Your typical day | Copy | "so the coach can" becomes "so your plan fits around it" (free users have no coach) |
| S08 | Building your plan | Copy | Failed state in Amber with a next step |
| S09 | Your plan | Visual | Pro: coach card orange, *Use this plan* neutral. Free: *Use this plan* orange |

### Home (F3a, F3)

| ID | Screen | Change | What changes |
|---|---|---|---|
| S10 | Home | **Big** | (1) Progress tiles replaced by the brand's **monthly look back** card in plain words: "This month: 11 workouts, bench press up 5 kg." No volume chart. (2) "Longest run: 6 weeks" removed (it is a streak). (3) Back-after-break never counts missed days: free line "Welcome back. Weights are 10% lighter today after 12 days off." (4) Heatmap squares use 4 Sage steps on Iron, today outlined in Chalk. (5) Today card *Start* is the one orange thing unless a coach card is showing |
| S11 | Choose routine | Visual | |

### Routines (F2, F2b)

| ID | Screen | Change | What changes |
|---|---|---|---|
| S30 | Routines | Visual | Coach card above the list means *New routine* is neutral |
| S31 | Routine editor | **Big** | Time bar: fits is Sage, over is Amber with `exclamationmark.circle`, never red. Suggestion lines rewritten as actions: "Add a pulling exercise to balance this routine." Delete confirmation keeps system red |
| S32 | Ready-made routines | Copy | No-match copy no longer says "coach" to free users. A **First month** group at the top for beginners (brand "ideas worth considering"; marked optional) |
| S33 | Routine preview | Copy | "Harder than your level" becomes "A step up from your level. You can still try it." in Sky, not a warning |
| S34 | Routine roadmap | Visual | Current step highlighted with Iron raised and a Chalk line, not orange. *Start* is orange |
| S35 | Add cardio or recovery step | Visual | |
| S14 | Exercise picker | Visual | Level shown as a plain chip, demo thumbnails |

### Workout (F3, F4, F5)

| ID | Screen | Change | What changes |
|---|---|---|---|
| S12 | Workout session | **Big** | Current step leads with the hero number ("42.5 kg × 8 to 12") and the reason underneath. Badges use the status colours. **First time on an exercise**: a line under the demo, "First time? Watch the loop, then go light." Exercise done: "Done. 3 sets of chest press." Between sets the screen is almost silent: rest timer and next number only. *Log set* is orange; camera button is Iron raised at the same height |
| S13 | Set confirm | **Big** | Hero numbers for weight and reps. Source label no longer says "coach" for free users: "Today's target", "Same as last set", "No history yet: pick a weight". Photo badges: High is Sage `checkmark` "Read from photo"; low confidence is Amber "Not sure about this one. Is it 40 kg?" Could not read: "Couldn't read the photo. Enter it by hand, it's already filled in." Save: light haptic, row settles into S12 |
| S16 | Session summary | **Big** | Leads with facts in plain words: "3 exercises, 9 sets. Next time: squat goes up 2.5 kg." No total volume. New best is the one cheer: "New best: 50 kg on the squat!" with Sage glow and one success haptic. Coach insight never mentions skipped sessions. Optional **reminder opt-in** after the first workout (see S52) |
| S20 | Camera | Visual | Guide frame and shutter in Chalk; no orange (the demo still frame may carry it) |
| S21 | Reading weight | Copy | "Reading the stack…" calm, *Enter it by hand* after 3 s |
| S22 | Camera access off | Visual | |
| S23 | Paywall | Copy | Headline line from the guide: "Snapset Pro reads your weights from a photo and plans with you." *Subscribe* orange; the free alternative is the same size, neutral. Failures in Amber |

### History (F6)

| ID | Screen | Change | What changes |
|---|---|---|---|
| S40 | Sessions | Copy | Empty state says "Finished workouts show up here." (tab name fixed: Home, not Workout) |
| S41 | Session detail | Visual | |
| S42 | Exercises | **Big** | "Best e1RM" removed from the list; each row shows its **best** (heaviest set, e.g. "60 kg × 5") |
| S43 | Exercise detail | **Big** | Top: "Best: 60 kg × 5". Chart shows the heaviest weight per workout, plain axis labels. The estimate moves under an info button: "The most you could probably lift once: about 70 kg." |

### Settings and the rest

| ID | Screen | Change | What changes |
|---|---|---|---|
| S50 | Settings | Copy | "Photo logging" section renamed **Snapset Pro**. *Coach tips* only shown to Pro. Sync line in Sky, never an error. New **Reminders** row (S52) |
| S51 | Export and import | Visual | |
| S52 | Reminders (new) | **New** | From brand section 9: opt-in, at most one reminder on planned training days, friendly copy ("Leg day is ready when you are."). Off by default. Asked once on S16 after the first workout, and in Settings |
| S36 | Exercise demo sheet | **Big** | Brand figure style (Iron figure, working muscle in Pin orange, no face). Cues stay at three |
| S37 | Machine settings | Visual | |
| S38 | Swap exercise | Visual | "Same muscles" in Sage, "Close match" in Sky, both with words |
| S60 | Coach card | **Big** | The visual spec in section 1. All example copy rewritten (F9) |
| S61 | Suggested routine | Copy | Trigger copy no longer compares with what they "should" have done |
| S62 | Suggestion line | Visual | Grey `info.circle`, rewritten lines |
| LA | Live Activity and widgets | **Big** | Hero number style on the Lock Screen and Dynamic Island, Graphite background, orange only on the progress ring of the rest timer. Large widget heatmap uses Sage steps |

**Totals:** 15 screens or components need a bigger change (S01, S03, S10, S12, S13, S16, S31, S36, S42, S43, S60, LA, plus new S52), about 20 need copy changes, the rest only follow the shared patterns.

## 3. Stale items fixed in flows.md while auditing

- "Everything else is local SwiftData" now says on-device SQLite (GRDB), matching ADR-001.
- Open questions said the rest timer was out of v1, but F2b and F12 include it. Removed the stale line.
- S40 empty state referred to a "Workout" tab, renamed Home on 2026-10-11.
- Principle P7 example updated to the guide's rewrite.

## 4. Not changed (worth a look)

- **"Get lean" goal name.** Kept, because it describes a goal and not a body. The brand rule is about praising actions. Say if you want "Lose fat" or "Get fitter" instead.
- **Plain-words glossary** (tap any gym word for a one-line explanation). The brand guide lists it as not decided, so it is not in the flows yet. It would fit the beginner audience well and would be a small task after Task 22.
