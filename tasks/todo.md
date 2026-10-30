# Task List: Snapset — Photo-Logged Gym Tracker (iOS)

Plan and rationale: [plan.md](plan.md). Paths below assume an Xcode project named `Snapset`; rename freely.

Standard verification for every app task: the project builds, unit tests pass (`xcodebuild test -scheme Snapset -destination 'platform=iOS Simulator,name=iPhone 17'`), and the manual check listed in the task is done. Every task that builds a screen also checks the result against the approved design in `design/` (light and dark, largest text size).

---

## Phase 0: Prove the differentiator

## Task 1: Vision accuracy spike on real gym photos

**Description:** Before any app code, measure whether a hosted vision model can read the selected weight from photos of pin-stack machines. Take about 30 photos in a real gym across at least 8 different machines (good and bad angles; stacks labelled kg, lb, both, and plate numbers only), record the true answer for each, and run them through a script that sends the image plus the fixed exercise list and asks for the structured output in the plan.

**Acceptance criteria:**
- [ ] A labelled set of at least 30 photos with true exercise, stack label type, unit and selected weight
- [ ] A script that prints, per stack label type: weight accuracy, whether the true exercise is in the top 3 candidates, latency, and cost per photo
- [ ] A short written result: which label types pass 80% weight accuracy, and the common failure cases

**Verification:**
- [ ] Script runs end to end and its numbers match a hand count on 5 photos
- [ ] Human reviews the results and makes the go / no-go call

**Dependencies:** None

**Files likely touched:**
- `spike/eval.py`
- `spike/labels.csv`
- `spike/RESULTS.md`

**Estimated scope:** Small

## Checkpoint: Go / no-go
- [ ] Weight accuracy at least 80% on the stack label types to be shipped
- [ ] Human decides: proceed, narrow to passing equipment types, or stop

---

## Phase 1: Design

Runs in parallel with Task 1. If the spike ends in "stop", only the photo flows are wasted; the tracker and coaching designs still apply.

## Task D1: Design principles and user flows

**Description:** Write down who the app is for and the conditions it is used in (one hand, between sets, sweaty fingers, poor gym lighting, 30–90 seconds of attention), then map every user flow as low-fidelity wireframes: first run and goal setup, build a routine, run a workout, log a set manually, log a set by photo, review history and maxes, hit the paywall. Include the empty, loading, error and offline states of each.

**Acceptance criteria:**
- [ ] Every screen needed by Tasks 2–12 appears in a flow, with its empty, loading and error states
- [ ] Logging a set by photo is at most 3 taps after the shutter; logging manually is at most 4
- [ ] A short list of design principles that later decisions can be checked against

**Verification:**
- [ ] Walk each flow start to finish on paper with no dead ends
- [ ] Human reviews and approves the flows

**Dependencies:** None

**Files likely touched:**
- `design/principles.md`
- `design/flows.md`
- Figma file (linked from `design/README.md`)

**Estimated scope:** Small

## Task D2: Visual system

**Description:** Define the look once so every screen reuses it: colour palette for light and dark (dark is the primary, gyms are dim), type scale built on Dynamic Type, spacing, and the handful of components the app is made of (set row, weight and reps stepper, exercise card, primary button, confidence badge, chart). Includes the app icon direction.

**Acceptance criteria:**
- [ ] Colours, type, spacing and components are named tokens, in both light and dark
- [ ] Text and controls meet WCAG AA contrast; every tap target is at least 44 pt, logging controls larger
- [ ] Components hold up at the largest Dynamic Type size without clipping

**Verification:**
- [ ] Contrast checked for every text and background pair
- [ ] Human approves the visual direction on two sample screens before the rest are drawn

**Dependencies:** Task D1

**Files likely touched:**
- `design/tokens.md`
- Figma file

**Estimated scope:** Small

## Task D3: High-fidelity screens and prototype test

**Description:** Draw every screen from the D1 flows with the D2 system, link them into a clickable prototype, and put it in front of three people who lift. The set-confirm screen gets the most attention: it is used dozens of times per workout and is shared by manual and photo logging.

**Acceptance criteria:**
- [ ] All screens and states from D1 exist in high fidelity, light and dark
- [ ] Three lifters complete "log a set by photo" and "log a set manually" on the prototype without help
- [ ] Problems found in testing are fixed in the designs or listed as accepted

**Verification:**
- [ ] Notes from the three sessions saved
- [ ] Human approves the final screens

**Dependencies:** Task D2

**Files likely touched:**
- Figma file
- `design/test-notes.md`

**Estimated scope:** Medium

## Checkpoint: Design
- [ ] Flows, visual system and screens approved by human
- [ ] Prototype tested with three lifters
- [ ] Design tokens ready to be turned into code in Task 2

---

## Phase 2: Usable tracker without photos

## Task 2: Project scaffold, data model, seed exercises

**Description:** Create the SwiftUI app with the D2 design tokens as a Swift theme and SwiftData models (`Exercise`, `Routine`, `RoutineItem`, `WorkoutSession`, `SetEntry`, `UserSettings`) and load a bundled list of about 60 exercises with equipment type on first launch.

**Acceptance criteria:**
- [ ] App launches to a tab shell (Workout, Routines, History, Settings)
- [ ] Seed exercises load exactly once and survive relaunch
- [ ] Settings switches between kg and lb; weights are stored in kg and converted for display

**Verification:**
- [ ] Unit test: seeding twice does not duplicate exercises
- [ ] Unit test: switching unit and back leaves stored weights unchanged
- [ ] Manual check: relaunch keeps settings

**Dependencies:** Task 1 (go decision), Task D2

**Files likely touched:**
- `Snapset/SnapsetApp.swift`
- `Snapset/Models.swift`
- `Snapset/Theme.swift`
- `Snapset/Resources/exercises.json`
- `Snapset/SettingsView.swift`
- `SnapsetTests/SeedTests.swift`

**Estimated scope:** Medium

## Task 3: Create and edit routines

**Description:** User can create a named routine, add exercises from the seed list, reorder and remove them, and set target sets per exercise.

**Acceptance criteria:**
- [ ] Create, rename and delete a routine
- [ ] Add, reorder and remove exercises within a routine
- [ ] Deleting a routine does not delete past workout sessions

**Verification:**
- [ ] Unit test for the delete rule
- [ ] Manual check: build a 3-day routine set

**Dependencies:** Task 2, Task D3

**Files likely touched:**
- `Snapset/RoutineListView.swift`
- `Snapset/RoutineEditorView.swift`
- `SnapsetTests/RoutineTests.swift`

**Estimated scope:** Small

## Task 4: Log a workout manually

**Description:** Start a session from a routine, and for each exercise log sets on a single confirm screen (exercise, weight, reps) with weight and reps pre-filled from the last session. This confirm screen is the one photo logging will reuse.

**Acceptance criteria:**
- [ ] Start a session, log sets, finish the session
- [ ] Weight and reps pre-fill from the most recent set of that exercise
- [ ] An interrupted session (app killed) is resumable with no lost sets

**Verification:**
- [ ] Unit test for the pre-fill lookup
- [ ] Manual check: kill the app mid-session and resume

**Dependencies:** Task 3

**Files likely touched:**
- `Snapset/WorkoutView.swift`
- `Snapset/SetConfirmView.swift`
- `SnapsetTests/PrefillTests.swift`

**Estimated scope:** Medium

## Task 5: History and personal maxes

**Description:** Show past sessions and, per exercise, the heaviest set and best estimated 1RM (Epley: weight × (1 + reps / 30)) with a simple chart over time using Swift Charts.

**Acceptance criteria:**
- [ ] Session list with drill-down to the sets logged
- [ ] Per-exercise page shows heaviest set, best estimated 1RM and a chart
- [ ] Units display according to settings

**Verification:**
- [ ] Unit test for the 1RM calculation, including the 1-rep case
- [ ] Manual check with a few seeded sessions

**Dependencies:** Task 4

**Files likely touched:**
- `Snapset/HistoryView.swift`
- `Snapset/ExerciseDetailView.swift`
- `Snapset/Maxes.swift`
- `SnapsetTests/MaxesTests.swift`

**Estimated scope:** Small

## Checkpoint: Tracker
- [ ] All tests pass, app builds clean
- [ ] A full workout is logged and reviewed on a physical phone in airplane mode
- [ ] Review with human before proceeding

---

## Phase 3: Photo logging

## Task 6: Vision proxy

**Description:** One serverless function that accepts a downscaled image plus context (unit, candidate exercise ids), calls the vision model with the prompt proven in Task 1, and returns the structured output. Holds the API key; validates and rate-limits requests.

**Acceptance criteria:**
- [ ] Returns the agreed JSON shape, or a typed error, for any input
- [ ] Rejects oversized bodies and non-image payloads; rate-limits per device
- [ ] Does not store images; API key is only in server configuration

**Verification:**
- [ ] The Task 1 photo set, run through the proxy, matches the spike's accuracy
- [ ] Manual check: oversized and garbage requests are rejected

**Dependencies:** Task 1

**Files likely touched:**
- `proxy/index.ts`
- `proxy/prompt.ts`
- `proxy/index.test.ts`

**Estimated scope:** Small

## Task 7: Photo capture pre-fills the confirm screen

**Description:** A camera button, shown only on machine exercises, takes a photo of the weight stack, sends it to the proxy, and opens the Task 4 confirm screen with exercise and weight pre-filled. The exercise defaults to the routine's next exercise unless the model is confident in another candidate.

**Acceptance criteria:**
- [ ] Photo to pre-filled confirm screen in one action
- [ ] The weight read and its unit are shown and editable; a stack labelled in the other unit is converted to the user's setting
- [ ] Low-confidence results are visibly marked rather than silently trusted

**Verification:**
- [ ] Unit test: decoding the proxy response, including a malformed one
- [ ] Manual check on a physical device with a real machine

**Dependencies:** Task 4, Task 6

**Files likely touched:**
- `Snapset/CameraCapture.swift`
- `Snapset/VisionClient.swift`
- `Snapset/SetConfirmView.swift`
- `SnapsetTests/VisionClientTests.swift`

**Estimated scope:** Medium

## Task 8: Corrections and failure paths

**Description:** Make the photo path safe to rely on in a gym: timeouts and offline fall through to manual entry, camera permission denial is handled, and every user correction is recorded alongside the model's guess for later evaluation.

**Acceptance criteria:**
- [ ] No network or a slow response lands on the manual confirm screen within a few seconds, with nothing lost
- [ ] Denied camera permission shows a clear path to manual entry and to Settings
- [ ] Each photo-logged set stores the model's guess and the final value

**Verification:**
- [ ] Unit test for the timeout fallback
- [ ] Manual check in airplane mode and with camera permission denied

**Dependencies:** Task 7

**Files likely touched:**
- `Snapset/VisionClient.swift`
- `Snapset/Models.swift`
- `Snapset/WorkoutView.swift`

**Estimated scope:** Small

## Checkpoint: Photo logging
- [ ] All tests pass, app builds clean
- [ ] In a real gym session, photo logging takes fewer taps than manual entry
- [ ] Review correction data with human: is accuracy holding at the Task 1 level?

---

## Phase 4: Goal-based coaching

## Task 9: Goal onboarding

**Description:** First-run screens that capture the goal (build muscle, get lean / lose fat, strength), experience level and training days per week, with a plain "not medical advice" notice. Editable later in Settings.

**Acceptance criteria:**
- [ ] Goal, level and days per week are stored and editable
- [ ] Onboarding is shown once and can be skipped (defaults to build muscle)

**Verification:**
- [ ] Manual check: fresh install, skip, and change later in Settings

**Dependencies:** Task 2

**Files likely touched:**
- `Snapset/OnboardingView.swift`
- `Snapset/Models.swift`
- `Snapset/SettingsView.swift`

**Estimated scope:** Small

## Task 10: Progression engine

**Description:** A pure function: given goal, exercise equipment and recent sets, return the next target (weight, rep range, sets). Goal sets the rep range (strength 3–6, muscle 6–12, lean 10–15); double progression adds the smallest load step once all sets reach the top of the range, and suggests a reduction after repeated misses.

**Acceptance criteria:**
- [ ] Deterministic output for a given history and goal
- [ ] Load steps respect unit and equipment (e.g. 2.5 kg barbell, next dumbbell size)
- [ ] No history returns a "find your starting weight" target rather than a number

**Verification:**
- [ ] Table-driven unit tests: progress, hold, reduce, no history, unit change

**Dependencies:** Task 2

**Files likely touched:**
- `Snapset/Progression.swift`
- `SnapsetTests/ProgressionTests.swift`

**Estimated scope:** Small

## Task 11: Next-session targets in the workout screen

**Description:** Show the engine's target next to each exercise during a session and use it as the pre-fill on the confirm screen. After a session, show a one-line summary of what progressed.

**Acceptance criteria:**
- [ ] Each exercise in a session shows its target weight and rep range
- [ ] Confirm screen pre-fills from the target when one exists
- [ ] Post-session summary lists exercises that will go up next time

**Verification:**
- [ ] Manual check: log two sessions and see the target rise after hitting the range

**Dependencies:** Task 4, Task 9, Task 10

**Files likely touched:**
- `Snapset/WorkoutView.swift`
- `Snapset/SetConfirmView.swift`
- `Snapset/SessionSummaryView.swift`

**Estimated scope:** Small

---

## Phase 5: Paid photo logging

## Task 12: Subscription and paywall

**Description:** Add one auto-renewing subscription with StoreKit 2, defined in a local StoreKit configuration file so it can be built and tested without an Apple Developer account. Tapping the camera button without an active subscription shows a paywall; manual logging and coaching stay free.

**Acceptance criteria:**
- [ ] Without a subscription the camera button opens the paywall, and manual entry is one tap away
- [ ] Purchase, restore, expiry and cancellation each put the app in the right state
- [ ] Nothing outside photo logging is gated

**Verification:**
- [ ] Unit test for the entitlement check using StoreKit Test
- [ ] Manual check in the simulator: buy, expire the subscription from Xcode, restore

**Dependencies:** Task 8

**Files likely touched:**
- `Snapset/Store.swift`
- `Snapset/PaywallView.swift`
- `Snapset/WorkoutView.swift`
- `Snapset/Products.storekit`
- `SnapsetTests/StoreTests.swift`

**Estimated scope:** Medium

## Task 13: Proxy verifies the subscription

**Description:** The app sends its signed StoreKit transaction with each photo request; the proxy verifies the signature and expiry before calling the vision model, and applies a monthly fair-use cap per subscriber. The cap value is undecided: it is one configuration setting, set generously during development and chosen at the Stable checkpoint. Without this, anyone who finds the proxy address gets the paid feature for free.

**Acceptance criteria:**
- [ ] Requests with a missing, expired, tampered or wrong-app transaction are rejected before any model call
- [ ] A subscriber over the monthly cap gets a clear error the app shows as "limit reached, log manually"
- [ ] Local StoreKit test transactions are accepted only when the proxy runs in development mode

**Verification:**
- [ ] Proxy tests for each rejection case and the cap
- [ ] Manual check: a plain request to the proxy without a transaction is refused

**Dependencies:** Task 6, Task 12

**Files likely touched:**
- `proxy/index.ts`
- `proxy/entitlement.ts`
- `proxy/entitlement.test.ts`
- `Snapset/VisionClient.swift`

**Estimated scope:** Medium

## Checkpoint: Stable
- [ ] All tests pass, app builds clean
- [ ] Two weeks of real workouts on your own phone with no lost data
- [ ] Human sets the subscription price and monthly photo cap from the measured cost per photo and real usage
- [ ] Human decides whether to buy the Apple Developer account and continue to release

---

## Phase 6: Release

## Task 14: Privacy, permissions and TestFlight

**Description:** Requires the Apple Developer account. Create the subscription in App Store Connect, add camera usage text, privacy manifest and App Store privacy answers reflecting that photos are sent for analysis and not stored, VoiceOver labels and Dynamic Type on the logging flow, then a TestFlight build.

**Acceptance criteria:**
- [ ] Permission text and privacy disclosures match what the app actually sends
- [ ] The full logging flow is usable with VoiceOver and at the largest text size
- [ ] A TestFlight build completes a workout and a sandbox purchase that the production proxy accepts

**Verification:**
- [ ] Manual accessibility pass on the workout, confirm and paywall screens
- [ ] TestFlight install on a clean device with a sandbox purchase

**Dependencies:** Task 11, Task 13

**Files likely touched:**
- `Snapset/Info.plist`
- `Snapset/PrivacyInfo.xcprivacy`
- `Snapset/SetConfirmView.swift`

**Estimated scope:** Small

## Checkpoint: Complete
- [ ] All acceptance criteria met
- [ ] All tests pass, builds clean
- [ ] Human approves for TestFlight distribution
