# Implementation Plan: Snapset — Photo-Logged Gym Tracker (iOS)

## Overview

An iOS app that tracks routines, weights and maxes, where logging a set starts with a photo instead of typing. The photo is read by a vision model that proposes the exercise and the loaded weight; the user confirms with one tap and adds reps. A rule-based coach then tells the user what to lift next time, tuned to their goal (build muscle, get lean / lose fat, strength).

## What was fixed in the original idea

| Original idea | Problem | Fix |
|---|---|---|
| "No need to manually enter progress" | A photo cannot show reps, sets, or effort. | Promise becomes **"confirm, don't type"**: photo fills exercise + weight, user taps reps (pre-filled from last session). |
| Photo detects the exercise | A close-up of a weight stack rarely shows which machine it belongs to. | Use context first: the next exercise in today's routine is the default guess. Vision only ranks candidates; user can change in one tap. |
| Photo detects the weight | Too broad to start with: barbell plates overlap and are seen edge-on. | **v1 photo logging covers pin-stack machines only**: read the number at the pin. Known traps: stacks labelled in both kg and lb, plates numbered 1–20 instead of weights, add-on weights. The reading is always editable and every correction is saved. Free weights are logged manually. |
| Photo logging for everyone | Each photo costs money to analyse. | The tracker and coaching are free; photo logging is a paid subscription, checked by the proxy. |
| Custom computer vision model | Months of data collection and training before anything works. | Use a hosted multimodal model (Claude) behind a thin proxy. Revisit on-device only if cost or latency forces it. |
| Progress guidance for lean / muscle / fat loss | Fat loss is mostly diet; training advice differs less than people expect. | Goal picks a rep range, weekly volume and progression rule. Nutrition is out of scope for v1. No medical claims. |
| Everything at once | Tracker, vision and coaching are three products. | Prove vision accuracy **before** building the app (Task 1). The tracker must be usable with manual entry alone. |

## Architecture Decisions

- **Design before app code.** Flows, a visual system and tested high-fidelity screens are approved before the first screen is built (Tasks D1–D3). Design conditions: one hand, between sets, dim gyms, so dark-first, large controls, minimum taps. The set-confirm screen is the centre of the app and gets the most design time.
- **SwiftUI + SwiftData, local-only storage.** No accounts, no sync, no backend database in v1. Smallest thing that works; iCloud sync can be added later through SwiftData's CloudKit option.
- **Vision via hosted multimodal model, called through a small proxy** (one serverless function). The API key must never ship inside the app binary. The proxy also gives one place to rate-limit.
- **Structured output contract** between app and proxy, fixed before UI work:
  `{ exerciseCandidates: [{id, confidence}], stackLabels: "kg" | "lb" | "both" | "plateNumbers", weight, unit, confidence }`
- **Photo logging is paid, everything else is free.** One auto-renewing subscription through StoreKit 2. The app sends its signed transaction with each photo and the proxy verifies it before calling the model, so the paid feature cannot be used by calling the proxy directly. Development and testing use Xcode's local StoreKit configuration, which needs no Apple Developer account.
- **Units: kg and lb, switchable in Settings at any time.** Weights are stored in one unit (kg) and converted for display, so switching never rewrites history.
- **No Apple Developer account until the app is stable.** A free Apple ID is enough to run on your own phone (builds expire after 7 days). The account is only needed for TestFlight and for real purchases, so that is the last task.
- **Manual entry is a first-class path**, not a fallback. Photo capture pre-fills the same confirm screen manual entry uses, so there is one logging UI.
- **Progression is rules, not machine learning**: double progression (hit the top of the rep range on all sets, then add the smallest load step). Estimated 1RM by the Epley formula.
- **Fixed seed exercise list** (about 60 common lifts) with equipment type. The model picks from this list by id; it never invents exercise names.

## Dependency Graph

```
Task 1 vision spike (go / no-go)
        │
Task 2 project + data model + seed exercises
        │
        ├── Task 3 routines ── Task 4 manual set logging ── Task 5 history + maxes
        │                              │
        │                     Task 6 proxy ── Task 7 photo capture → confirm
        │                                            │
        │                                     Task 8 corrections + failure paths
        │
        └── Task 9 goal onboarding ── Task 10 progression engine ── Task 11 next-session targets

Task 8 ── Task 12 subscription + paywall ── Task 13 proxy verifies subscription
                                                     │
                                  (Task 11 too) ── Task 14 release (needs Apple Developer account)
```

Design runs alongside the spike: D1 → D2 → D3. Task 2 also needs D2 (tokens); every screen-building task from Task 3 on needs D3.

Tasks 3–5 and 9–10 can run in parallel once Task 2 is done. Tasks 6–8 depend only on Task 4.

## Task List

Full acceptance criteria are in [todo.md](todo.md).

### Phase 0: Prove the differentiator
- [ ] Task 1: Vision accuracy spike on real gym photos

### Checkpoint: Go / no-go
- [ ] Machine stack weight read correctly on at least 80% of photos; human reviews the misses and decides to proceed, narrow scope, or stop

### Phase 1: Design (parallel with Task 1)
- [ ] Task D1: Design principles and user flows
- [ ] Task D2: Visual system
- [ ] Task D3: High-fidelity screens and prototype test

### Checkpoint: Design
- [ ] Flows, visual system and screens approved; prototype tested with three lifters

### Phase 2: Usable tracker without photos
- [x] Task 2: Project scaffold, data model, seed exercises
- [x] Task 3: Create and edit routines
- [x] Task 4: Log a workout manually
- [x] Task 5: History and personal maxes

### Checkpoint: Tracker
- [ ] A full workout can be logged and reviewed on a real phone, offline

### Phase 3: Photo logging
- [ ] Task 6: Vision proxy
- [ ] Task 7: Photo capture pre-fills the confirm screen
- [ ] Task 8: Corrections and failure paths

### Checkpoint: Photo logging
- [ ] Logging a set by photo takes fewer taps and less time than manual entry in a real gym session

### Phase 4: Goal-based coaching
- [x] Task 9: Goal onboarding
- [x] Task 10: Progression engine
- [ ] Task 11: Next-session targets in the workout screen

### Phase 5: Paid photo logging
- [ ] Task 12: Subscription and paywall
- [ ] Task 13: Proxy verifies the subscription

### Checkpoint: Stable
- [ ] Used for real workouts for two weeks on your own phone without data loss; human decides whether to buy the Apple Developer account

### Phase 6: Release
- [ ] Task 14: Privacy, permissions and TestFlight

### Checkpoint: Complete
- [ ] All acceptance criteria met, tested on a physical device, ready for TestFlight

## Out of scope for v1

Photo logging for barbells, dumbbells and plate-loaded machines; accounts and sync; Apple Watch; rep counting from video; form feedback; nutrition and calorie tracking; social features; Android. Each is a separate plan.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Vision misreads the stack (dual kg/lb labels, plate numbers, worn stickers, pin hidden) | High | Task 1 spike before any app work; reading always editable; log corrections |
| Exercise cannot be inferred from a stack close-up | High | Default to the routine's next exercise; vision only re-ranks candidates |
| Per-photo API cost exceeds subscription revenue | Medium | Downscale images before upload; fair-use cap per subscriber in proxy; compare a smaller model in Task 1 |
| Proxy used without paying | High | Proxy rejects requests without a valid signed transaction (Task 13); until then the proxy URL stays private |
| Purchases cannot be tested for real without the developer account | Medium | Local StoreKit configuration covers the purchase flow; sandbox test is part of Task 14 |
| Poor gym connectivity | Medium | Photo path times out after a few seconds into manual entry; all data local |
| Photos include other people | Medium | Do not store photos on the server; state this in the privacy text; keep local copy only if user opts in |
| Coaching read as medical advice | Medium | Plain disclaimer in onboarding; conservative load steps; no injury or diet advice |

## Decisions made

- Photo logging starts with machines only.
- kg and lb both supported, switchable in Settings.
- App is free; photo logging is paid.
- Solo developer; Apple Developer account bought only once the app is stable.
- Photo logging is sold as a subscription, not credit packs.
- Minimum iOS version is iOS 18.

## Open Questions

- Where to design: Figma (assumed; I can draw screens there once it is connected) or straight in SwiftUI previews?
- Any brand direction already in mind (colours, mood, apps you like the look of)?
- Price and monthly fair-use cap: undecided. Task 1 measures cost per photo; the cap is a single proxy setting (Task 13) chosen at the Stable checkpoint, so nothing is blocked until then.
