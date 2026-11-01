# Snapset design principles

Task D1. Every later design and build decision should be checkable against this page. If a screen breaks a principle, either the screen changes or the exception is written down here.

## Who it is for

People who have decided to get serious about the gym but are still new to it. They train a few times a week, want to know what to put on the bar next time, and feel overwhelmed by gym apps full of charts and jargon. They are still learning the exercises, so every exercise shows how it is done. They do not want to type. Voice, colour and type are in [brand/brand-guide.md](brand/brand-guide.md). (Updated 2026-10-31: the earlier text assumed people who already know the exercises.)

## Conditions of use

| Condition | What it means for the design |
|---|---|
| One hand, often the weak one, while the other holds a bottle or a handle | Primary actions live in the bottom third of the screen, within thumb reach |
| Between sets, 30 to 90 seconds of attention, breathing hard | One decision per screen; the answer is already filled in |
| Sweaty or chalky fingers, sometimes gloves | Logging controls at least 60 pt, everything else at least 44 pt; no small text fields; no swipe-only actions |
| Dim or harsh gym lighting, phone at arm's length | Dark first, high contrast, weights and reps as the largest text on screen |
| Phone on the floor or a bench between sets | The current exercise and next target readable at a glance, without unlocking a flow |
| Patchy signal in basements | Everything except photo reading works offline; offline is never an error screen |

## Principles

1. **Confirm, don't type.** Every field arrives pre-filled (from the photo, the coach's target, or the last set). The keyboard is a last resort; steppers and chips come first.
2. **Thumb zone, glance distance.** The action you take next is the biggest thing in the bottom third. The number you care about (weight, reps) is the biggest thing on screen.
3. **The model suggests, the lifter decides.** Anything the photo reader filled in is visibly marked, shows how sure it is, and changes in one tap. Nothing read from a photo is saved without the Save tap.
4. **Logging never gets stuck.** Offline, timeout, denied camera, paywall, monthly limit: every one of them is one tap from manual entry, with whatever was already known carried over.
5. **Saved means saved.** A set is stored the moment Save is tapped. Killing the app mid-workout loses nothing. Mistakes are fixed with Undo or by editing the set, not prevented with "Are you sure?" dialogs.
6. **Free looks finished, Pro has the coach.** The Coach exists only in Pro. Free users get plain, basic suggestions with no coach label or highlight, and the layout simply has no coach card instead of an empty or locked one. Pro (photo logging and all AI) is offered only at the camera, at *Build one for me*, in Settings and once after onboarding.
7. **Coach in one line.** A target is a number plus a short reason ("You got 12 on every set last time. Add 2.5 kg."). No streaks, no guilt, no medical or diet claims.
8. **Dark first, colour never alone.** Designed for dark mode, then checked in light. State (low confidence, progression, error) always has an icon or word as well as a colour.
9. **Same screen, two ways in.** Manual and photo logging end on the same Set confirm screen, so there is one thing to learn and one thing to polish.
10. **Coach, not chat.** The AI (Pro) never appears as a chat box. It speaks through a coach card at the moment a decision is made, gives the reason, and can always be dismissed. Rules on the phone set the numbers. The coach card is the only highlighted element on its screen.
11. **Ask once, only what the coach uses.** Every onboarding question feeds a coaching decision, can be skipped, and is pre-filled from Apple Health where possible. Speaking is always offered next to typing for longer answers.
12. **Recognise before reading, see how it's done.** Every exercise carries its demo animation (a still thumbnail in lists, the full loop one tap away), so the right exercise and its form are clear at a glance. Reduce Motion shows still frames.
13. **Offline first.** Everything is saved on the phone first and synced later. Only photo reading, AI, purchases, password reset and sync need a connection, and each falls back without blocking. Sync is never shown as an error.
14. **Know the next step.** A routine is a roadmap: every step (warm-up, exercises, cardio, recovery, cool-down) in order, with its start time and duration, and the current step always obvious.
15. **The gym is the context.** Remember each machine's settings, offer a swap when a machine is busy, and keep the screen readable and awake on a bench (gym mode).

## Interaction budgets

These are the numbers D3 testing checks against.

| Action | Budget | Counted from |
|---|---|---|
| Log a set by photo | 3 taps or fewer | after the shutter |
| Log a set manually | 4 taps or fewer | from the workout screen |
| Start the planned workout | 2 taps | from app launch |
| See what to lift next | 0 taps | visible on the workout screen |

How taps are counted: a tap is any touch that changes something. The budget assumes the pre-filled value is within one step of the truth (for example the reps differ by one). If the photo reading is wrong by more than that, typing a weight is allowed to exceed the budget, and the correction is recorded for later evaluation (Task 8).
