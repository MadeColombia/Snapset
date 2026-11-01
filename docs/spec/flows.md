# Snapset user flows (low fidelity)

Task D1. Visual wireframes of every flow are in the Snapset Flows artifact linked from [README.md](README.md). This file is the written source: the screen list, each flow step by step, every state, tap counts, and the dead-end walkthrough. Principles referenced as P1 to P15 are in [principles.md](principles.md).

**Revision 6 (2026-11-01): brought in line with the approved [brand guide](brand/brand-guide.md).** Copy, colours and a few screens changed; the screen-by-screen list is in [screen-audit.md](screen-audit.md) and the pre-brand version is kept in [archive/flows-v1-2026-10-12.md](archive/flows-v1-2026-10-12.md). Visual rules for every screen are in "Brand patterns" below.

## Brand patterns (revision 6)

Every screen follows these, so they are not repeated per flow. Source: brand guide sections 3 to 8.

- **One orange thing per screen.** Pin orange is the primary button, unless the screen shows a coach card (S60), which then takes the orange and the primary button becomes the *neutral primary* (Chalk fill, Graphite text). Text on Pin orange is Graphite.
- **No red.** Warnings, low confidence, failed saves and over-time are Amber with `exclamationmark.circle` and a next step. Only iOS destructive buttons (Delete account, Delete routine) keep the system red.
- **Status colours always with an icon and a word.** Up: Sage `arrow.up`. Hold: Sky `equal`. A bit lighter: Amber `arrow.down`. Saved, new best: Sage `checkmark`.
- **Hero number.** Weight and reps use SF Pro Rounded Semibold with monospaced digits, 64 pt scaled with Dynamic Type, and are the largest thing on the screen.
- **Number first, reason second, plain words.** No 1RM, volume, PR or load in the interface.
- **No guilt, no streaks.** Never count missed days or skipped sessions.
- **Motion.** Smooth springs without bounce, 0.2 to 0.35 s. Saving a set: light haptic, the row settles in. New best: Sage glow and one success haptic, no confetti. Reduce Motion: fades and still frames.
- **Copy.** Sentence case, no em dashes, at most one "!" per screen and only for a real win.

## App shell

Four tabs: **Home**, **Routines**, **History**, **Settings** (Task 2 said Workout; renamed because the first tab is now an overview, F3a). Onboarding is shown once before the shell. The Set confirm screen and the camera open as sheets over the workout session.

## Free and Pro (decided 2026-10-11, revised)

All AI is in the paid plan (working name **Snapset Pro**), together with photo logging. **The Coach exists only in Pro.** Free users get plain **suggestions**: short and basic, mostly while building their own routine. They are never called "coach" and never get the coach's highlight.

Two components, visibly different:
- **Coach card (Pro, S60).** Accent border, "Coach" label, personal reason in full sentences, actions. The one highlighted element on a screen.
- **Suggestion line (free, S62).** No border, no label, no accent: a small grey info icon, one short line in secondary text, and at most one text action ("Add"). It sits inline in the list, at the same weight as the rows around it.

| Spot | Free | Pro |
|---|---|---|
| First plan at onboarding (S09) | Closest match from the ready-made library, with a plain line: "Matches 3 days, 45 min" | Coach builds a plan around the typical day, with a personal reason |
| Building your own routine (S31) | Basic suggestion lines: "Add a pulling exercise to balance this routine.", "There's room for one more exercise.", "Add a warm-up." | Coach card with detailed, personal suggestions and one-tap chips |
| Weight targets and up, down, hold badges (S12) | Same for everyone: rules set every number. The badge shows the plain rule ("Add 2.5 kg. You got 12 on every set last time.") | Same badge; the coach can explain in more detail |
| Back after a break (S10) | A plain info line, because the weights change: "Welcome back. Weights are 10% lighter today after 12 days off." | Coach card with the reason and the plan to climb back |
| Tips during a workout (S12) | None | Coach tip that fits the person's recent sets |
| Session summary (S16) | Facts only: new bests, what goes up next time, days this week | Plus one coach insight |
| Routine change when the real pace differs | None | Coach suggests an adapted routine (S61) |
| Build one for me (S32) | Normal button that opens the paywall | Coach builds a routine |
| Photo logging (camera) | Camera opens the paywall | Reads the stack |

The free app still looks finished: no empty slots, greyed-out cards, locks or teasers where the coach would be. Where Pro has a coach card and free has nothing, the layout simply doesn't have that card. When Pro users are offline, coach cards fall back to the free suggestion lines.

Where Pro is offered: the camera button, *Build one for me*, Settings, and once after onboarding for people who answered the typical-day question, with *Not now* as an equal-sized button. Nowhere else (P6).

## Offline first (decided 2026-10-11)

Everything is stored on the phone first and synced in the background (P13). Offline, these still work: logging, routines, the library, history, Home, rule-based coaching, settings, and onboarding. Only these need a connection: photo reading, AI coaching, buying or restoring Pro, password reset, and syncing. Each of them falls back without blocking (P4). Sync status is never an error: Settings shows "Last synced 5 min ago" or "Will sync when you're online".

## Screen inventory

| ID | Screen | Used by tasks | States designed |
|---|---|---|---|
| S01 | Welcome | 9, 17 | default, Apple or Google cancelled, failed, offline |
| S71 | Create account | 17 | default, email in use, weak password, offline |
| S72 | Check your email | 17 | sent, resend cooling down |
| S73 | Log in | 17 | default, wrong details, email uses another method, too many tries, restoring, session expired |
| S74 | Reset password | 17 | default, sent |
| S75 | Account (in Settings) | 17 | verified, not verified, Hidden by Apple, sign-in methods, log out, delete account |
| S05 | Connect Apple Health | 16 | default, allowed, denied |
| S06 | About you | 9 | pre-filled from Health, empty, edit mode |
| S02 | Goal | 9 | default, edit mode (from Settings) |
| S03 | How you train (level, days, session length, where) | 9 | default, edit mode |
| S07 | Your typical day | 9, 15 | empty, typing, listening (mic), mic permission denied, edit mode |
| S08 | Building your plan | 15 | building, slow, failed or offline |
| S09 | Your plan | 15 | suggested plan, regenerated, template fallback |
| S04 | Units | 2, 9 | folded into S06 (kg or lb chosen next to weight) |
| S10 | Home (overview) | 4, 11, 18 | new account (empty heatmap), ready, rest day, no routines, session in progress (resume), day tapped |
| S11 | Choose routine | 4 | list, routine with no exercises (disabled) |
| S12 | Workout session | 4, 7, 11, 12 | first set, mid-session, exercise done, all done, no history target, camera for free users (opens Pro), camera limit reached |
| S13 | Set confirm | 4, 7, 8, 11 | manual pre-fill (last set), manual pre-fill (coach target), no history, photo high confidence, photo low confidence, photo picked a different exercise, unit converted, plate numbers, could not read, offline or timeout, editing a saved set, save failed |
| S14 | Exercise picker | 3, 4, 7 | list, search, no results, filtered by equipment |
| S16 | Session summary | 11 | progressed, nothing progressed, first session ever |
| S20 | Camera | 7 | viewfinder, torch on |
| S21 | Reading weight | 7, 8 | reading, slow (over 3 s, shows Enter manually), cancelled |
| S22 | Camera access off | 8 | denied |
| S23 | Paywall | 12 | price loading, ready, price failed or offline, purchasing, Ask to Buy pending, purchase failed, restore found nothing, subscription ended |
| S30 | Routines | 3 | empty, list, coach suggestion |
| S31 | Routine editor | 3, 15, 18 | new (no exercises), fits, over time, room for one more, coach suggestions, reorder, delete confirmation |
| S32 | Ready-made routines | 3, 18 | default (filtered by profile), filtered, no match |
| S33 | Routine preview | 3, 18 | default, a step up from your level |
| S40 | History: sessions | 5 | empty, list |
| S41 | Session detail | 5 | default |
| S42 | History: exercises | 5 | empty, list with each exercise's best set |
| S43 | Exercise detail | 5 | one session (no trend yet), several sessions (chart of heaviest weight), units switched |
| S50 | Settings | 2, 9, 12, 16 | free, subscribed, subscription ended, Health connected, Health off |
| S60 | Coach card, Pro only (component on S09, S10, S12, S16, S30, S31) | 15 | weights up, weights down after a break, hold, tip, new routine suggested, hidden when AI is unavailable |
| S61 | Suggested routine preview (Pro) | 15 | preview, accepted, dismissed |
| S62 | Suggestion line, free (component on S09, S10, S31) | 3, 10 | info, with one action |
| S34 | Routine roadmap | 3, 18 | default, with cardio and recovery, above your level |
| S35 | Add cardio or recovery step | 3 | cardio, recovery, warm-up, cool-down, rest |

Every exercise shown anywhere (S10, S12, S13, S14, S16, S31, S34, S41 to S43) carries its demo animation thumbnail (see "Exercise demo animations" below).

Added 2026-10-12:

| ID | Screen | Used by tasks | States designed |
|---|---|---|---|
| S36 | Exercise demo sheet | 22 | playing, Reduce Motion (still frames) |
| S37 | Machine settings | 20 | empty, filled, suggested from photo (Pro) |
| S38 | Swap exercise (machine busy) | 21 | alternatives, none fit the time |
| S51 | Export and import (Settings) | 19 | export, import preview, unrecognised names, done |
| S52 | Reminders (Settings, and asked once on S16) | 19 | off, on with days, notifications denied |
| LA | Lock Screen Live Activity and widgets | 19 | resting, in a set, timed step |

Loading states only exist where something is slow: the photo reading (S21), StoreKit (S23) and the AI building a plan (S08). Everything else is on-device SQLite (GRDB, ADR-001) and loads instantly, so it has no spinner by design. Offline only affects S08, S21, S23 and the AI-written coach cards; it is never an error anywhere else (P4).

## F0. Account: Apple, Google or email (Task 17)

Decided in the thread: **Sign in with Apple, Sign in with Google, and email and password** (Apple and Google added 2026-10-12). Default provider: Firebase Auth, which handles all three, plus verification email and password reset. Default: your profile, typical day and workouts are synced to the account so they come back after a reinstall or on a new phone. The phone keeps a full local copy, so logging still works offline.

1. **S01 Welcome.** The app icon, the word mark "Snapset" and the tagline *Know what to lift next.* No orange button on this screen. Then, stacked full width: *Continue with Apple* (Apple's standard black or white button, first, as Apple's guidelines expect equal or higher prominence), *Continue with Google* (Google's standard button), *Continue with email* (opens S71), and *I already have an account* (text, opens S73).
   - Apple and Google create the account and log in with the same tap; there is no separate sign-up for them. They skip S71 and S72 (the email is already verified) and go straight to onboarding (F1), with the name pre-filled when the provider shares it.
   - Apple's *Hide My Email* is supported: the account works with the relay address, and Settings shows it as "Hidden by Apple".
   - Cancelled in the system sheet: back to S01, no message.
   - Failed (Amber): "Couldn't sign in with Apple. Try again, or continue with email."
   - Offline: the Apple and Google buttons show "Needs a connection" under them; *Continue with email* still offers *Continue offline* (S71).
2. **S71 Create account.** Email, password (with a show or hide toggle and the rule shown before typing: "At least 8 characters"), *Create account*. Links to the Terms and Privacy Policy under the button. iOS Password AutoFill and strong password suggestion are supported, so most people never type the password.
   - Email already used: "There's already an account for this email." *Log in instead*.
   - Weak password: the rule line turns Amber with `exclamationmark.circle` and the reason.
   - Offline: "You're offline. You can start now and we'll create your account when you're back online." *Continue offline* (primary), *Try again*. Everything is saved on the phone; the account is created and synced automatically when the connection returns, and Settings shows "Account waiting for connection" until then. If the email turns out to be taken at that moment, Settings asks for a different email or a log-in, and nothing logged is lost.
3. **S72 Check your email.** "We sent a link to ethan@… Tap it to confirm your email." *Open Mail*, *Resend email* (disabled for 60 s after each send), *Change email*. Onboarding continues straight away (S05); the account works unverified, and a small Sky `info.circle` banner on S10 reminds them until the email is confirmed. Default: verification is not blocking, so nobody is stuck at the gym waiting for an email.
4. **S73 Log in.** *Continue with Apple* and *Continue with Google* at the top, then "or", then email, password, *Log in*, *Forgot password?*.
   - Same email, different method (for example signed up with Google, now trying email): "This email uses Google to sign in." with *Continue with Google*. After signing in, the person can link both methods in Settings.
   - Wrong email or password: "Email or password is incorrect." (Never says which one.)
   - Too many tries: "Too many attempts. Try again in a few minutes or reset your password."
   - After logging in on a new phone: "Restoring your workouts…" then straight to S10; onboarding is skipped because the profile already exists.
5. **S74 Reset password.** Email, *Send reset link*, then "If there's an account for this email, we sent a reset link." The reset itself happens on Firebase's web page from the email.
6. **Account in Settings (S75).** Email (with "Not confirmed, resend" when unverified), *Sign-in methods* (Apple, Google, Email: shows which are linked, with *Link* for the others; at least one must stay), *Change password* (email accounts only), *Log out*, *Delete account*.
   - Log out: "Log out? Your workouts are saved to your account." Data on the phone is cleared after logout.
   - Delete account: required by the App Store for apps with sign-up. Confirmation sheet: "This deletes your account, profile and all workouts. It can't be undone." Email accounts type their password to confirm; Apple and Google accounts confirm by signing in again with that provider. For Apple accounts, Snapset also revokes the Apple sign-in token, as Apple requires. Workouts already saved in Apple Health stay there.
   - Session expired (password changed on another phone): S73 with "Please log in again."

## F1. First run: profile, goal and your typical day (Tasks 9, 15, 16)

Starts right after the account is created (F0). Only the goal is required; every other answer can be skipped and filled in later from Settings. Each answer exists because the coach uses it (P10).

*Skip setup* is offered on every onboarding screen. It stores defaults (goal: build muscle, beginner, 3 days, 60 minutes, full gym, unit from the region), offers a template routine, and goes to S10.

1. **S05 Connect Apple Health** (optional). Opens with "Let's set up your first week. You can skip any question." Then: "Snapset can read your height, weight and age, and save your workouts to Apple Health so they show up in the Fitness app." *Connect Apple Health* opens the system permission sheet; *Not now*. Either way continues.
   - Allowed: S06 arrives pre-filled. Denied or Not now: S06 is empty. Never asked again in onboarding; Settings has the switch (F10).
2. **S06 About you.** Name (for greetings only), birth year, height, body weight with kg or lb next to it (this sets the app's unit; reason shown: "Used to suggest starting weights and for Apple Health"), and sex (optional, "used only to estimate calories for Apple Health"). Values from Health are labelled "From Apple Health". Each field is a picker wheel or stepper, not a keyboard, except the name. *Continue*.
3. **S02 Goal.** Three large cards, each with one plain line and the reps second: Build muscle ("Get bigger and stronger", 6 to 12 reps), Get lean ("Fitter, with lighter weights and more reps", 10 to 15 reps), Strength ("Lift heavier, fewer reps", 3 to 6 reps). Under them, the plain notice: "Snapset suggests weights and reps. It is not medical advice. Check with a professional if you have an injury or condition." Tapping a card selects it and continues.
4. **S03 How you train.** Two questions get the most space: "How many days a week?" (2 to 6) and "How much time do you have per workout?" (30 / 45 / 60 / 90 min chips, or *Other* for a 20 to 120 min stepper in 5 min steps). Then level chips, worded for beginners and with the first one preselected: *New to the gym* / *Some experience* / *Experienced* (stored as beginner, intermediate, advanced) and where you train (Full gym / Basic gym / Home with dumbbells). *Continue*. The time answer becomes the budget for the time bar in the routine editor (F2).
5. **S07 Your typical day.** "Tell us how a normal day goes so your plan fits around it." A large text box with an example in grey ("I work 9 to 6 at a desk, train around 7 pm, sleep about 6 hours, walk the dog every morning"). A large mic button: tap to talk, tap again to stop; the words appear in the box as you speak and can be edited. *Continue* or *Skip*.
   - Listening: the mic button pulses and shows "Listening… tap to stop". Speech is turned into text on the phone; only the text is sent to the coach.
   - Mic permission denied: "Microphone is off for Snapset. You can type instead, or turn it on in Settings."
   - Shown under the box: "Snapset Pro's AI coach uses this to plan your training." (Final privacy wording comes with the privacy policy in Task 14.) Free users' answers are stored on the phone and only sent if they get Pro.
   - After this screen, people who wrote or said something see the onboarding paywall once (F7), with *Not now* as an equal button.
6. **S08 Building your plan** (Pro only; free users go straight to S09 with the library match). Progress with what is happening in plain words ("Fitting 3 days around your evenings"). After 8 seconds: *Use a starter plan instead*.
   - Failed or offline (Amber): "Couldn't build your plan right now. A starter plan is ready instead." *Try again* / *Use a starter plan* (the best match from the ready-made library, S32, picked by goal, days and time; no AI). The AI plan can be requested later from the Routines tab.
7. **S09 Your plan.** Free: the best match from the ready-made library with a template reason ("Matches 3 days, 45 min, full gym"). Pro: the suggested routines (for example "Upper / Lower, 4 days") with one line on why ("Short evening sessions, so 45 minutes with supersets"), each routine showing about how long it takes, its level, and its exercises with icons. *Use this plan* (primary), *Try another* (regenerates, limited to a few times), *Build my own* (empty Routines). Accepting creates the routines and goes to S10 ready.

Taps with Health connected and answers pre-filled: Connect, Allow (system), Continue, goal card, Continue, Skip or Continue, Use this plan = 7, plus whatever the person types or says. Skip path: 1 tap.

## F2. Routines: ready-made, estimated, built your way (Tasks 3, 15, 18)

Every routine card, everywhere in the app (S09, S10, S30, S32, S33, S61), shows the same three facts: **estimated time** ("about 50 min"), **level** (Beginner / Intermediate / Advanced) and the exercise icons. Both estimates are calculated on the phone, so they are free and work offline.

How the time estimate works (Task 18): for each exercise, sets x (about 40 s of work + rest for the goal: strength 2.5 min, build muscle 1.5 min, get lean 1 min) + about 1 min to set up the machine, plus 5 min of warm-up. It is labelled "about" and rounded to 5 minutes. After a few workouts it learns from the person's real durations ("Your Push Day usually takes 55 min").

How the level works: each seed exercise has a skill level (a leg press is beginner, a barbell back squat is intermediate, a snatch would be advanced). The routine takes the highest exercise level, raised by one step if the weekly volume is high for that level. The person's own level is set in S03; a routine above it shows "A step up from your level. You can still try it." in Sky next to the badge, as information, never a block.

1. **S30 Routines.**
   - Empty: "Start from a ready-made routine or build your own." Two big options: *Browse ready-made routines* (S32) and *New routine* (S31). If onboarding produced a plan, it is already here.
   - List: each routine as a card with name, about 50 min, level, exercise icons, last done date. A coach card above the list when the coach has a routine suggestion (F9).
2. **S32 Ready-made routines.** A library of routines written with AI and reviewed before release, bundled in the app (works offline, costs nothing per use). Filters: goal, days per week, time (30 / 45 / 60 / 90), where you train, level. Defaults to the person's own answers from onboarding, so the first screen already fits them. Each card: name, about 45 min, level, icons. Grouped as plans ("Upper / Lower, 4 days") and single routines ("Full body, 45 min").
   - At the top: *Build one for me* (AI, F9) creates a routine from the profile and typical day, shown with the same card and the same preview.
   - No match for the filters: "No ready-made routine fits all of these. Try a longer time, or tap Build one for me." with *Build one for me*.
   - **First month** group at the top while the level is *New to the gym* (optional, from the brand guide's ideas): 4-week beginner routines with machines and lighter starting weights.
3. **S33 Routine preview.** Exercises with icons, sets and rest, the estimate and level, and a one-line description ("Machines only, good for a first month"). *Add to my routines* (copies it so it can be edited), *Back*.
4. **S31 Routine editor.** Name, then the **time bar** at the top: "About 52 of your 45 min" filled against the person's session time from S03.
   - Over budget: the bar turns Amber with `exclamationmark.circle` (never red), and a line under it: "This routine might take you longer than your 45 min, about 7 min over." with a suggestion, "Drop a set from 3 exercises, or remove Pec deck." The routine can still be saved.
   - Room left: "You still have about 12 min. Room for one more exercise." Suggestions below point to ones that fit.
   - Fits: "About 43 of your 45 min." Bar in Sage. No message.
   - Rows: drag handle, icon, exercise name, sets stepper (default 3), each row with its own minutes ("about 8 min"). Swipe or *Edit* to remove (both, never swipe-only).
   - **Suggestions** under the list, the "complement" options. Free: up to 3 plain suggestion lines (S62) from simple rules, each with an *Add* action: "Add a pulling exercise to balance this routine.", "There's room for one more exercise.", "Add a warm-up.", "Add some cardio this week." Pro: a coach card with detailed, personal suggestions as one-tap chips ("Add Face pull: after a desk day it balances all the pressing", "Swap Leg extension for Leg press, fewer machine changes"). Offline, Pro shows the free lines. *Hide suggestions* turns them off for this routine.
   - *Add exercise* opens S14. *Save*.
   - Saving with no exercises is allowed; the routine shows "No exercises yet" and cannot be started (S11 disabled state).
5. **S14 Exercise picker.** Search field, equipment filter chips (Machine, Barbell, Dumbbell, Cable, Bodyweight), list with icon, name, level and minutes per 3 sets. Machine exercises show a small camera mark so people learn which ones photo logging covers. Multi-select, *Add (n)*; the time bar stays visible at the top while picking.
   - No results: "No exercise called "xyz". Snapset uses a fixed list for now."
6. **Delete**: confirmation sheet "Delete Push Day? Your past workouts stay in History." This is the one confirmation dialog, because a routine is planning work that Undo would not reliably cover. Deleting never removes sessions (Task 3 rule).

## F2b. Routine steps and the roadmap (Tasks 3, 4, 18)

A routine is an ordered list of **steps**, not just exercises. It is shown as a **roadmap**: a vertical line of steps from top to bottom, each with its start time from 0:00, so the person knows exactly what to do and in what order.

Step types:

| Step | What it holds | Example on the roadmap |
|---|---|---|
| Warm-up | Duration, what to do (light cardio, mobility list) | 0:00 · Warm-up · 5 min easy bike |
| Strength exercise | Sets, rep range, rest between sets (editable, default from the goal), target from the rules | 0:05 · Chest press · 3 × 8–12 · rest 90 s |
| Cardio | Machine or activity (treadmill, bike, rower, stairs, elliptical, walk or run outside), duration, intensity (easy, moderate, hard), optional distance | 0:42 · Cardio · 15 min treadmill, moderate |
| Recovery | Stretching, foam rolling or mobility: duration and a short checklist | 0:57 · Recovery · 5 min stretch: hips, chest, back |
| Rest | A pause between blocks (for example between strength and cardio) | 0:40 · Rest · 2 min |
| Cool-down | Duration, what to do | 1:02 · Cool-down · 3 min walk |

"Recovery time" is covered three ways: rest between sets (per exercise), recovery steps inside a routine, and rest days in the week plan (Home shows "Rest day" on the right days). Default chosen; say if you meant something else.

**S34 Routine roadmap** (opened by tapping a routine anywhere): the vertical roadmap with every step, icon, start time and duration, the total "about 62 min" and level at the top, and *Start* (orange) at the bottom. The current step is marked with Iron raised and a Chalk line, never orange. Strength steps show the target ("42.5 kg × 8–12"). This replaces the plain list in the routine preview (S33) too.

**S31 Routine editor** adds *Add step* with a choice: Exercise (opens S14), Cardio, Recovery, Warm-up, Cool-down, Rest. Cardio and recovery open a small sheet (S35) with type chips, a duration stepper (in 1 minute steps) and intensity chips. Every step can be dragged; the start times and the time bar update live. Time bar and alerts count all steps, not just exercises.

**S12 Workout session as a roadmap.** The session is the same roadmap, live:
- Done steps collapse to one line with a check and what was done ("Chest press · 3 sets · 42.5 kg").
- The current step is expanded and highlighted: for strength, the target and *Log set* as before; for cardio, recovery, warm-up and cool-down, a large timer with *Start*, *Pause* and *Done* (and *+1 min*), plus the checklist for recovery.
- Upcoming steps show start time and duration, dimmed but readable.
- A rest timer starts automatically after each logged set, using that exercise's rest time, and can be skipped.
- Steps can still be done in any order: tapping a step makes it current.
- Finishing a cardio step logs its duration (and distance if entered). The whole session is still saved to Apple Health as one workout (F10).

## F3a. Home: how you're doing (Task 18)

The first tab is **Home** (renamed from Workout). It answers "how am I doing?" at a glance and still starts today's workout in 2 taps. Order from top to bottom:

1. **Greeting and today.** "Evening, Ethan." Today's routine card (name, about 50 min, level, icons) with *Start*. Rest day: "Rest day. Next up: Legs on Thursday." with *Train anyway*.
2. **Coach card** when there is something to say (after a break, a routine suggestion; F9).
3. **Gym days heatmap**, like GitHub's contribution graph: one square per day, columns are weeks, about 20 weeks fit on a phone, scrolling left shows the whole year. A square is empty on rest days and gets darker with more sets that day (4 shades). Today has an outline. Tap a square: "Tue 7 Oct, Push Day, 52 min, 18 sets", tap again to open the session (S41).
   - Squares use 4 steps of Sage on Iron (more sets, stronger Sage); today has a Chalk outline.
   - Under it, plain numbers: "This week 2 of 3 days", "47 workouts this year". ("Longest run" removed in revision 6: it is a streak.)
   - The weekly target (days from S03) is the measure, not a daily streak, so a planned rest day never breaks anything (P7: no guilt).
   - Accessibility: VoiceOver reads a summary ("Trained 14 of the last 30 days, 2 of 3 this week") and each square's date and workout; colour is never the only signal (P8), the tapped day always shows its numbers.
4. **Monthly look back** (replaces the progress tiles in revision 6): one short card in plain words, "This month: 11 workouts, bench press up 5 kg.", plus new bests this month with the exercise thumbnail. No charts. Tap goes to History (S40 or S43).
5. States:
   - New account, no workouts: the heatmap shows empty weeks with "Your first workout fills the first square." The look back card is hidden until the first workout.
   - Session in progress: the resume banner sits above everything (F3).
   - No routines: today's card is replaced by *Browse ready-made routines* and *Build my own*.

## F3. Run a workout (Tasks 4 and 11)

1. **S10 Home.**
   - No routines (onboarding skipped or plan declined): "Get a plan built around your week" (opens S08) and *Build my own* (S31).
   - Ready: a greeting by name, a card for the next routine in rotation ("Push Day, last done Tuesday, 5 exercises", with exercise icons) and *Start*. *Choose another routine* goes to S11. For Pro, a coach card (S60) sits above it when there is something to say; for free, a plain line only when the weights changed after a break. *Start* is orange unless the coach card is showing.
   - Session in progress (app was killed or user left): a banner at the top, "Push Day in progress, 7 sets logged", *Resume*. Starting another routine while one is open asks "Finish Push Day first?" with *Resume it* / *Finish and start new*.
2. **S12 Workout session.** Header: routine name, elapsed time, *Finish*. The routine's roadmap (F2b), live; the current step is expanded:
   - Exercise demo thumbnail and name, then the target as the hero number: "42.5 kg × 8 to 12", "3 sets" under it, with an up, down or hold badge and the one-line reason underneath ("You got 12 on every set last time. Add 2.5 kg."). For Pro, an optional coach tip (F9). No history: "Find your starting weight: pick one you can lift 10 times with good form."
   - First time on this exercise: a line under the demo, "First time? Watch the loop, then go light."
   - Between sets the screen is almost silent: the rest timer and "Next: 42.5 kg × 10".
   - Sets already logged as rows (weight x reps), tap a row to edit it (S13 editing).
   - Bottom of the screen, in thumb reach: *Log set* (primary, orange, at least 60 pt tall) and, for machine exercises only, a camera button of the same height beside it (Iron raised).
   - After a save: the new row appears with an *Undo* toast for 5 seconds. A rest timer runs between sets. When the target sets are done, the step collapses with a check and "Done. 3 sets of chest press.", and the next step expands. Any step can be tapped to make it current; order is a suggestion.
   - Camera button states: available, free user (looks the same, no lock; tapping opens S23), limit reached (opens S13 with the limit banner).
3. **Finish** goes straight to **S16 Session summary** (no confirm dialog, P5). It leads with facts in plain words: "3 exercises, 9 sets. Next time: squat goes up 2.5 kg.", then "Going up next time" listing exercises whose target rises ("Leg press: 120 kg next time, 5 kg more"). A new best is the one cheer on the screen: "New best: 50 kg on the squat!" with a Sage glow and one success haptic. Nothing went up: "Same weights next time. Try for one more rep." First session ever: "First workout done. Next time's weights start from today.", and once only, the reminder opt-in (S52): "Want a reminder on your training days?" *Turn on* / *Not now*, same size. For Pro, a coach card with one insight when there is one (F9), and "Saved to Apple Health" when connected (F10). Buttons: *Done* (to S10), *Back to workout* (reopens the session if finished by accident).

## F4. Log a set manually (Task 4) and edit a set

1. In **S12**, tap *Log set*. (tap 1)
2. **S13 Set confirm** opens as a sheet:
   - Exercise row at the top (the current exercise; tap to change via S14).
   - Weight: hero number with the unit, minus and plus buttons stepping by the equipment's smallest load (2.5 kg barbell, next dumbbell size, the machine's stack step). Tapping the number opens a number pad as a last resort (P1).
   - Reps: hero number with minus and plus.
   - "Last time: 42.5 × 12, 42.5 × 11" under the numbers, a *Warm-up* chip and a note button (F12).
   - Source label under the numbers, so the lifter knows where the pre-fill came from: "Today's target", "Same as last set", or "No history yet: pick a weight". (Free users have no coach, so the label never says coach.)
   - *Save set* at the bottom, full width, orange, at least 60 pt. Saving gives a light haptic and the new row settles into S12.
3. Adjust weight one step (tap 2) and reps one step (tap 3), then *Save set* (tap 4). Back on S12 with the Undo toast.

**Tap count: 2 when the pre-fill is right, 4 with one weight and one reps adjustment. Budget 4. Pass.**

- **Editing a saved set**: same S13 with the saved values, *Save changes* and a *Delete set* text button. Delete uses Undo, not a dialog.
- **Save failed** (storage error, should be rare): the sheet stays open with values intact and an Amber line, "Couldn't save this set. Tap Save again." Nothing is lost (P5).

## F5. Log a set by photo (Tasks 7 and 8)

1. In **S12**, on a machine exercise, tap the camera button. Not subscribed: go to F7. Camera permission never asked: the system prompt appears first; denied: **S22**.
2. **S20 Camera.** Full-screen viewfinder with a guide frame and the hint "Fit the pin and the number in the frame." Exercise name at the top so the lifter knows what Snapset expects. Torch toggle (dim gyms). *Enter manually* text button. Shutter at the bottom centre.
3. Shutter. The photo freezes into **S21 Reading weight** with a progress indicator. After 3 seconds an *Enter manually* button appears; after the timeout (proposed 6 seconds, set in Task 8) it falls through to S13 automatically.
4. **S13 Set confirm, filled from the photo.** Same screen as F4 (P9), with:
   - Weight marked "Read from photo" with a confidence badge: Sage `checkmark` when sure, Amber `exclamationmark.circle` "Not sure about this one. Is it 40 kg?" when not.
   - Reps pre-filled from the coach target or last set.
5. Adjust reps if needed (tap 1), *Save set* (tap 2).

**Tap count after the shutter: 1 when the reading and reps are right (Save), 2 with a reps adjustment, 3 with one correction to weight or exercise. Budget 3. Pass.**

Photo result variants on S13, each one tap from correct (P3):

| Variant | What the lifter sees |
|---|---|
| High confidence | Weight with "Read from photo" and a Sage `checkmark` |
| Low confidence | Weight outlined in Amber with "Not sure about this one. Is it 40 kg?" and `exclamationmark.circle`; still pre-filled, still one tap to Save |
| Different exercise | The model's pick is shown with "Detected Seated row" and the other top candidates (including the routine's expected exercise) as chips: one tap switches |
| Other unit on the stack | "Stack reads 100 lb, shown as 45 kg" under the weight |
| Plate numbers only | "This stack shows plate numbers (plate 7). Check the weight." Weight falls back to last time for this exercise and is marked in Amber |
| Could not read | Amber banner "Couldn't read the photo. Enter it by hand, it's already filled in." Weight from last set or target |
| Offline or timed out | Sky banner "No connection, so the photo wasn't read. The weight is filled in from last time." Same fallback values |
| Monthly limit reached | Sky banner "You've used this month's photo reads. Log by hand until 1 Nov." Camera button shows the limit state for the rest of the month |

Every variant stores the model's guess and the final saved value (Task 8), invisibly.

- **S22 Camera access off.** "Snapset needs the camera to read the weight stack. You can still log by hand." Buttons: *Log manually* (primary, opens S13) and *Open Settings*.

## F6. Review history and maxes (Task 5)

1. **S40 History, Sessions** (segmented control: Sessions / Exercises).
   - Empty: "Finished workouts show up here." No button; the tab bar already leads to Home.
   - List grouped by week: routine name, date, sets, duration.
2. **S41 Session detail.** Each exercise with its sets (weight x reps), sets logged by photo marked with a small camera icon. Tap an exercise to go to S43.
3. **S42 History, Exercises.** Every exercise ever logged, each with its best (heaviest set, "60 kg × 5"). Empty state same as S40.
4. **S43 Exercise detail.**
   - Top: "Best: 60 kg × 5" as the hero number. Under an info button, the estimate in plain words: "The most you could probably lift once: about 70 kg." (Epley, stored for coaching, never called 1RM in the interface.)
   - Chart of the heaviest weight per workout over time, plain axis labels, Sage line.
   - One session only: a single point and "Log this exercise again to see a trend."
   - Below: every set ever logged, newest first.
   - All weights in the unit from Settings (Task 2); switching units changes display only.

## F7. Hit the paywall (Task 12)

Entry points: the camera button on S12, *Build one for me* in the library (S32), Settings, and once after onboarding (see Free and Pro). Never anywhere else (P6).

1. **S23 Paywall** (sheet). Headline: "Snapset Pro", with the plain line "Snapset Pro reads your weights from a photo and plans with you." No pressure words, no countdowns. Benefit lines: "Log sets with a photo", "A coach that plans around your week", "Routines that adapt to your real pace", and "Everything else stays free". The headline highlights what was tapped (the photo line from the camera, the coach line from Build one for me). Then the price and period from StoreKit, *Subscribe* (primary, orange), *Restore purchase*, and the free alternative for that entry point as an equal-sized button: *Log manually instead* from the camera (opens S13, Task 12), *Browse ready-made routines* from Build one for me, *Not now* from onboarding.
2. States:
   - Price loading: the price line shows a placeholder; *Subscribe* disabled until the product loads.
   - Price failed or offline: "Couldn't load the price. Check your connection." *Try again*; manual stays available.
   - Purchasing: *Subscribe* shows progress; the system purchase sheet appears.
   - Success: the paywall closes and the thing they tapped continues straight away (camera opens, or the routine starts building), so the lifter finishes what they started.
   - Cancelled in the system sheet: back to the paywall, no message.
   - Pending (Ask to Buy): "Waiting for approval. Log manually for now." Closes on *Log manually instead*.
   - Failed (Amber): "The purchase didn't go through. You weren't charged." *Try again*.
   - Restore found nothing: "No subscription found for this Apple ID."
   - Subscription ended: headline becomes "Your subscription has ended"; the rest is the same.

## F8. Settings (Tasks 2, 9, 12)

**S50 Settings**, grouped:
- Account: S75 (F0).
- You: name, birth year, height, body weight, sex (S06 in edit mode); Your typical day (S07 in edit mode, text or mic).
- Units: kg / lb segmented control. Changes display immediately everywhere.
- Training: Goal, Level, Days per week, Session length, Where you train. Each opens S02 or S03 in edit mode. Changing the goal shows "Targets will use the new rep range from your next workout" and offers a rebuilt plan (F9).
- Coach (Pro only, hidden for free): Tips on or off.
- Reminders (S52): off by default; when on, pick the planned days. At most one reminder on a planned training day, written like a friend: "Leg day is ready when you are." Never about streaks or missed days. Notifications denied: "Notifications are off for Snapset." with *Open Settings*.
- Apple Health: Connected or off, *Open Health settings* (F10).
- Snapset Pro: status (Not subscribed / Active, renews 1 Nov / Ended), *Subscribe* or *Manage subscription*, *Restore purchase*.
- Workout: *Gym mode by default* on or off, *My gyms*.
- Data: *Export all workouts (CSV)* and *Import from another app* (S51, F12).
- About: the not-medical-advice notice, privacy line ("Photos are sent to read the weight and are not stored"), version.

## F9. AI coach, Pro only, no chat (Tasks 10, 11, 15)

The coach never has a chat box. It speaks through one component, the **coach card (S60)**: an Iron card with a 1 pt Pin orange border, a "Coach" label in Pin orange, the message in Chalk and its actions as text buttons. It is the screen's one orange thing. It is placed where the decision happens, always with the reason in one line and a way to say no (P3, P7, P10).

Who decides what:
- **Weights and reps are calculated by rules on the phone** (Task 10 progression engine): up after hitting the top of the range, hold, down after repeated misses, and down after a break (see below). Same input always gives the same number, works offline, and is unit-tested.
- **The AI** (through the proxy) reads the profile, your typical day and the training history, and does what rules can't: writes and adapts routines, picks the tip that fits, and explains changes in plain words. It can't invent a weight; any number it mentions comes from the rules.

Where the coach card appears (Pro wording shown; the free wording for each spot is in Free and Pro above):

| Place | Example | Actions |
|---|---|---|
| S10 Home, after a break | "Welcome back, Ethan. Today's weights are about 10% lighter so you can ease in. They climb back over the next 2 workouts." | *Got it*, *Use my usual weights* |
| S12 next to an exercise target | Badge: Sage ↑ "Add 2.5 kg. You got 12 on every set.", Amber ↓ "A bit lighter today, 5 kg less. Let's build back up.", Sky = "Same weight. Aim for 12 on every set." | Tap the badge for the reason |
| S12 tip on an exercise | "Try a one-second pause at the bottom. It makes the last reps count." | *Hide tips for this exercise* |
| S16 Session summary | "Shoulder press is up 10% this month. Thursday evening is a good fit for legs." | *Done* |
| S10 or S30, routine suggestion | "Your weeks have had 2 workouts lately. A 2-day full-body plan would fit them better." | *See plan* (S61), *Not now* |

Consistency rule (lowering after a break, Task 10): if an exercise hasn't been trained for a set number of days, the next target drops by a step that grows with the gap (starting values to tune: 8+ days a small drop, 15+ days about 10%, 30+ days back to the last comfortable weight). Missing planned sessions repeatedly over 3 to 4 weeks is what triggers a routine suggestion, never a guilt message.

**S61 Suggested routine preview.** Side by side: current routine and the suggested one, with exercises (and icons) and the one-line reason. *Switch* replaces the routine (old one kept in History), *Not now* hides the suggestion for 2 weeks.

States:
- Free users: no coach cards at all; the plain suggestion lines from Free and Pro instead. Pro offline, AI unavailable or over the limit: coach cards fall back to those suggestion lines. Nothing waits on the network (P4).
- No history yet: no badges; the "Find your starting weight" target from F3.
- The person changed their goal or typical day in Settings: a card on S10 offers "Rebuild your plan for the new goal?"

## F10. Apple Health and the Fitness app (Task 16)

1. Connected in onboarding (S05) or later from Settings (S50, *Apple Health*).
2. **Reads:** height, body weight, birth date and sex, to pre-fill S06, and body weight changes later (shown on S06 in Settings as "Updated from Apple Health").
3. **Writes:** when a workout is finished (S16), Snapset saves it to Apple Health as a Traditional Strength Training workout with its start, end and duration, so it appears in the Fitness app and counts toward the rings. The summary shows "Saved to Apple Health". Sets and reps stay in Snapset; the Fitness app shows the workout, not the sets.
4. States:
   - Not connected: S16 shows nothing about Health; S50 shows *Connect Apple Health*.
   - Permission denied or later turned off in the Health app: S50 shows "Apple Health is off for Snapset" with *Open Health settings*. Workouts keep saving in Snapset.
   - Save failed: summary line "Couldn't save to Apple Health. Snapset will try again." and it retries on next launch.
   - Workout deleted in Snapset: it is also removed from Apple Health.

## Exercise demo animations (replaces exercise icons, decided 2026-10-12)

Every exercise has a short looping **demo animation** of the movement instead of a static icon, so people both recognise it and see how to do it.
- **Small, in lists** (rows, cards, picker, roadmap, History): a 32 to 40 pt thumbnail that shows the key frame. It plays only for the current step on the roadmap, so screens don't fill with moving things.
- **Large, in the demo sheet (S36)**: opened by tapping any thumbnail. Plays the full loop with 3 short form cues ("Back flat against the pad", "Push without locking the elbows", "Two seconds down"), the muscles worked, and the equipment. *Close* returns to exactly where the person was. Available offline (bundled with the app).
- **Reduce Motion** on, or Low Power Mode: the still key frame replaces every animation, and the demo sheet shows 3 numbered still frames instead of the loop.
- One consistent style for all about 60 seed exercises (same figure, angle and colours), decided in D2. Source is open: commission them, license an existing library, or draw them in-house. Licensing cost and file size are risks to check before D2 commits (see todo.md).

The camera screen keeps a still frame of the expected exercise, and VoiceOver reads the exercise name for every thumbnail.

## F12. Logging basics (Tasks 4, 19)

Things every serious tracker has, now part of v1:
- **Last time, visible.** On S12 and S13, under each set being logged: "Last time: 42.5 × 12, 42.5 × 11, 42.5 × 10" in secondary text. It's information, the pre-fill still comes from the target.
- **Warm-up sets.** On S13, a *Warm-up* toggle (chip) next to the reps. Warm-up sets show with a "W" mark, are lighter by default (50% of the target), and don't count toward progression, maxes or volume.
- **Notes.** A note per exercise in a routine (sticky, shown every time: "Seat on 4, grip wide") and a note per set (one-off: "Left shoulder sore"). Added from a small note button on S13 and on the exercise row. Typing is fine here because it's optional. Dictation works through the keyboard mic.
- **Supersets and circuits.** In the routine editor, select 2 or more exercises and choose *Group as superset*. On the roadmap they show as one bracketed step ("Superset A: Chest press + Seated row, 3 rounds"). During the session, after logging a set of one, the next exercise in the group becomes current automatically, and the rest timer only runs after the last exercise in the round. Time estimates account for the shorter rests.
- **Rest timer on the Lock Screen and Dynamic Island.** While a session runs, a Live Activity shows the current step, the rest countdown, and the next set's target. Buttons on it: *Skip rest*, *+30 s*. Works with the phone locked on the bench.
- **Home Screen widget.** Small: this week's days against the target. Medium: today's routine with about how long it takes and a *Start* tap that opens the session. Large: the gym-days heatmap.
- **CSV export and import, in Settings (S51).** *Export all workouts (CSV)* creates a file with one row per set (date, routine, exercise, set type, weight, unit, reps, note) and opens the share sheet. *Import from another app* accepts CSV exports from Strong and Hevy and Snapset's own format: pick a file, see a preview ("214 workouts, 38 exercises, 3 not recognised"), map the unrecognised exercise names to the seed list or skip them, then *Import*. Imports run on the phone, offline.
- **Apple Watch app**: later, not in v1. Listed in plan.md as the next step after release.

## F13. What sets Snapset apart (Tasks 20, 21)

**Machine memory.** Every machine has its own settings (seat height, back pad, handle position, pin start). Snapset remembers them per exercise, and per gym when the person trains in more than one.
- **S37 Machine settings**, opened from a small "Settings" chip on the exercise's roadmap step and on S13. Rows with steppers or chips: seat, back pad, handles, range limiter, plus a free note. Defaults are the fields that machine type usually has.
- The next time that exercise is current, its settings show at the top of the step: "Seat 4 · Back pad 2 · Handles wide". No tap needed (P1).
- With Pro, the photo taken to read the weight can also suggest the machine's settings when they're visible (seat numbers are often printed). The suggestion is marked "From photo" and is never saved without a tap (P3). Free users fill them in by hand once.
- Gyms: Settings has *My gyms* (name only). Home and the session header show the current gym, picked automatically from the last session and changeable in one tap. The location is never tracked.

**Busy-machine swap.** On the current strength step, *Machine busy?* opens **S38 Swap exercise**: 3 alternatives from the seed list that work the same muscles and fit the time left, each with its demo thumbnail, level and "same muscles" or "close match". One tap swaps it for today only. The routine itself doesn't change unless *Always use this* is ticked. Works offline and is free (rules from the seed list's muscle and equipment data). Pro adds a coach line on why the pick fits.

**Gym mode.** A switch in the session header (and in Settings as the default). While on:
- The screen stays awake for the whole session.
- *Log set*, the steppers and the timer get bigger (logging controls at least 80 pt), and everything else on the step hides except the target and last time.
- Weight and reps are the largest text on screen, readable from the bench at arm's length.
- Taps register on press, not release, and swipe gestures are off to avoid mistakes with sweaty hands.

**Typical-day planning (Pro).** Already designed in F1 and F9.

## Walkthrough: no dead ends

Each screen and how you leave it. Checked by walking every flow above from start to finish.

| Screen | Ways out |
|---|---|
| S01, S71 to S74 | Create account, Log in, Forgot password, Back, Open Mail, Resend |
| S05 to S09 | Continue, Skip (S01, S05, S07), Back, Use a starter plan (S08), Build my own (S09) |
| S10 | Heatmap day (S41), progress tile (S40, S43), Start (S12), Choose another (S11), Resume (S12), Build a routine (S31), tabs |
| S11 | Pick routine (S12), Close |
| S12 | Log set (S13), Camera (S20, S22 or S23), tap set (S13 edit), Finish (S16), tabs stay reachable |
| S13 | Save, Close (discard, values were pre-filled so nothing typed is lost beyond this set), Change exercise (S14) |
| S14 | Pick or Add, Cancel |
| S16 | Done (S10), Back to workout (S12) |
| S20 | Shutter (S21), Enter manually (S13), Close (S12) |
| S21 | Result (S13), Enter manually (S13), Timeout (S13), Cancel (S12) |
| S22 | Log manually (S13), Open Settings (iOS Settings), Close |
| S23 | Subscribe (S20 on success), Log manually (S13), Restore, Close |
| S36 | Close (back to where you were) |
| S37, S38 | Save, Swap, Always use this, Cancel |
| S51 | Export (share sheet), Import, Skip unrecognised, Cancel |
| S52 | Turn on, Not now, Open Settings, Back |
| S30 to S33 | New, Browse, Build one for me, Add to my routines, Edit, Save, Delete, Back |
| S40 to S43 | Drill down, Back, tabs |
| S50 | Each row, Back |
| S60 | Its action, dismiss; never blocks the screen under it |
| S61 | Switch, Not now, Back |

Result: no screen without a way out, and every photo and paywall path reaches S13 in one tap.

## Open questions (defaults picked, flag if wrong)

- **Login.** Decided: Apple, Google, and email and password (F0). Open: default provider Firebase Auth, and whether workouts sync to the account in v1 (default yes, so a reinstall loses nothing).
- **Pro name and price.** "Snapset Pro" is a working name; price is set at the Stable checkpoint.
- **Plan regenerations.** Default: 3 tries per day for *Try another*.

- **Workout without a routine.** Not in the plan's tasks, so v1 requires a routine. Default: no quick or empty workout in v1.
- **Plate-number stacks.** v1 asks the lifter to check the weight. Remembering "plate 7 = 45 kg on this machine" could come later if the Task 1 spike shows these stacks are common.
- **Custom exercises.** The plan fixes the seed list. Default: no custom exercises in v1; the picker's no-results state says so.
- **Photo timeout.** Proposed 3 seconds to show *Enter manually*, 6 seconds to fall through. Final values belong to Task 8 once the spike measures latency.
