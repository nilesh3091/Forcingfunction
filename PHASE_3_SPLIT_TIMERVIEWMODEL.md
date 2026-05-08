# PHASE 3 — SPLIT TIMERVIEWMODEL

> **Goal:** Break the ~1,000-line `TimerViewModel` “god object” into ≤ 5 components, each ≤ 250 LOC and independently testable, while preserving behavior and protected UI surfaces.
>
> **Time:** ~2 weeks.
>
> **Risk:** Medium (concurrency + lifecycle recovery).
>
> **Non-negotiables:** Do not touch protected duration-setting UI surfaces in `TimerView.swift`. Do not edit `ForcingFunction.xcodeproj/project.pbxproj` directly.

---

## 📍 CURRENT STATUS — single source of truth

```
═══════════════════════════════════════════════════════════
  ACTIVE PHASE      : 3 — Split TimerViewModel
  PHASE STARTED     : 2026-05-08
  LAST COMPLETED    : 3.2 — Introduce `TimerStatePersistence` (single Codable blob)
  CURRENTLY ON      : (none)
  NEXT TO DO        : 3.3 — Introduce `SessionRecorder` actor (repo writes)
  PHASE COMPLETE    : ⛔️ no
═══════════════════════════════════════════════════════════

STEP CHECKLIST:

  [x] 3.0  Setup & baseline (branch + baseline tag)
  [x] 3.1  Extract `TimerEngine` + unit tests
  [x] 3.2  Introduce `TimerStatePersistence` (single Codable blob)
  [ ] 3.3  Introduce `SessionRecorder` actor (repo writes)
  [ ] 3.4  Formalize `PomodoroCoordinator` + wire existing modes
  [ ] 3.5  Introduce `FocusSessionStore` facade + rewire views
  [ ] 3.6  Protocol-front coordinators (notifications/live activity/bg/widget)
  [ ] 3.7  Delete or shrink `TimerViewModel` (≤ 200 LOC composer)
  [ ] 3.8  Fix Live Activity push-token leak (audit noted in roadmap)
  [ ] 3.9  Final verification + tag phase done

LEGEND:  [ ] not started   [~] in progress   [x] done   [-] skipped (with reason)
```

---

## ✅ Phase-wide exit criteria

- `TimerViewModel.swift` is **deleted** OR ≤ **200 LOC** and only composes injected components.
- Core responsibilities split into ≤ 5 components (targets):
  - `TimerEngine` (≤ 200 LOC)
  - `SessionRecorder` (≤ 150 LOC, `actor`)
  - `TimerStatePersistence` (≤ 120 LOC)
  - `PomodoroCoordinator` (≤ 100 LOC)
  - `FocusSessionStore` (≤ 200 LOC, `ObservableObject`)
- The four legacy lifecycle routines are consolidated into **one** explicit recovery routine in `TimerStatePersistence`.
- Test target is ≥ **100 unit tests**, all green (run once at Phase end).
- Build stays green after each step (`xcodebuild build` minimum gate).

---

## 🔧 Verification command (minimum gate, every step)

```bash
xcodebuild build \
 -project ForcingFunction.xcodeproj \
 -scheme ForcingFunction \
 -destination 'generic/platform=iOS Simulator' \
 -quiet
```

---

## 🚫 DO NOT (Phase 3)

- Do **not** touch the protected duration-setting UI in `TimerView.swift` (calendar strip, draggable bottom handle, MM:SS digit drag, ±5 stepper buttons, now-line/elapsed-fill/live tick).
- Do not edit `ForcingFunction.xcodeproj/project.pbxproj`.
- Do not introduce new dependencies.
- Do not change persistence schema (Phase 2 just landed SwiftData; Phase 4+ will evolve models deliberately).

---

## ✂️ FILES IN SCOPE (Phase 3)

This phase is code-moving + API shaping. We expect **new files** in `ForcingFunction/` and edits to the timer surface area.

**Allowed to modify/add:**
- `ForcingFunction/TimerViewModel.swift` (eventually deleted or reduced)
- `ForcingFunction/TimerView.swift` (wiring only; do not touch protected duration UI)
- `ForcingFunction/SettingsView.swift` (wiring only if needed)
- `ForcingFunction/ForcingFunctionApp.swift` (wiring only if needed)
- `ForcingFunction/LiveActivityManager.swift` (Step 3.8 only)
- New files under `ForcingFunction/` for:
  - `TimerEngine.swift`
  - `TimerStatePersistence.swift`
  - `SessionRecorder.swift`
  - `PomodoroCoordinator.swift`
  - `FocusSessionStore.swift`
  - protocol-front coordinators + adapters (Step 3.6)
- `ForcingFunctionTests/*` (tests added throughout)
- `PHASE_3_SPLIT_TIMERVIEWMODEL.md` (status updates)

Anything else: out of scope. Stop and ask.

---

## STEP 3.0 — Setup & baseline

```bash
git status                                 # must be clean
git checkout -b refactor/phase-3-split-timerviewmodel
git tag phase-3-baseline
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
```

Update STATUS block (set started date, `[ ] 3.0` → `[x] 3.0`, NEXT TO DO = 3.1), then:

```bash
git add PHASE_3_SPLIT_TIMERVIEWMODEL.md
git commit -m "chore: phase-3 baseline"
git tag phase-3-step-0-done
```

Stop and ask user before 3.1.

---

## STEP 3.1 — Extract `TimerEngine` + unit tests

**Goal:** Pure timer math (start/pause/resume/tick/remaining) with wall-clock correctness. **No I/O.**

**Action:**
- Create `ForcingFunction/TimerEngine.swift`.
- Move timer math/state out of `TimerViewModel` into `TimerEngine` with a narrow API.
- Make `TimerEngine` `@MainActor` (UI-coupled) and deterministic.

**Tests:**
- Create/extend tests to cover:
  - pause/resume sequences
  - drift vs wall clock (remaining time stays correct after app background)
  - expiry behavior

**Verify:**
```bash
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
```

**Commit + tag:**
```bash
git add ForcingFunction/TimerEngine.swift ForcingFunction/TimerViewModel.swift ForcingFunctionTests PHASE_3_SPLIT_TIMERVIEWMODEL.md
git commit -m "refactor: extract TimerEngine from TimerViewModel"
git tag phase-3-step-1-done
```

Stop and ask user before 3.2.

---

## STEP 3.2 — Introduce `TimerStatePersistence` (single Codable blob)

**Goal:** Replace scattered `@AppStorage` timer keys with **one** Codable blob and a single recovery routine.

**Action:**
- Create `ForcingFunction/TimerStatePersistence.swift`.
- Define a single `Codable` snapshot struct (what’s needed to restore an in-flight timer).
- Implement:
  - `load()` → snapshot?
  - `save(_:)`
  - `clear()`
  - `recoverIfNeeded(...)` (the single consolidated lifecycle routine)

**Verify:**
```bash
grep -rn '@AppStorage\\("' --include='*.swift' ForcingFunction/TimerViewModel.swift
# Expect: timer state keys are reduced/removed in favor of the blob.

xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
```

**Commit + tag:**
```bash
git add ForcingFunction/TimerStatePersistence.swift ForcingFunction/TimerViewModel.swift ForcingFunctionTests PHASE_3_SPLIT_TIMERVIEWMODEL.md
git commit -m "refactor: persist in-flight timer state as single snapshot blob"
git tag phase-3-step-2-done
```

Stop and ask user before 3.3.

---

## STEP 3.3 — Introduce `SessionRecorder` actor (repo writes)

**Goal:** All session persistence writes go through an `actor`, not the UI store.

**Action:**
- Create `ForcingFunction/SessionRecorder.swift` as an `actor`.
- It translates timer events into repository writes (start/pause/resume/complete/cancel).
- It owns “current session identity” (so we don’t scatter “ensure current session exists” logic).

**Tests:**
- cancel-under-15-min (if that policy exists in current behavior)
- partial-cancel
- expired-session-on-launch

**Verify:**
```bash
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
```

**Commit + tag:**
```bash
git add ForcingFunction/SessionRecorder.swift ForcingFunction/TimerViewModel.swift ForcingFunctionTests PHASE_3_SPLIT_TIMERVIEWMODEL.md
git commit -m "refactor: move session persistence into SessionRecorder actor"
git tag phase-3-step-3-done
```

Stop and ask user before 3.4.

---

## STEP 3.4 — Formalize `PomodoroCoordinator` + wire existing modes

**Goal:** The “what comes next” logic becomes an injected dependency.

**Action:**
- Create `ForcingFunction/PomodoroCoordinator.swift`.
- Define a protocol for next-session decisions (strict vs free-flow).
- Wire the existing mode toggle (added in Phase 1) through the coordinator rather than embedding branching in the UI store.

**Tests:**
- Exhaustive mapping for `(current session kind, completed count, settings) → next kind`.

**Verify:**
```bash
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
```

**Commit + tag:**
```bash
git add ForcingFunction/PomodoroCoordinator.swift ForcingFunction/TimerViewModel.swift ForcingFunctionTests PHASE_3_SPLIT_TIMERVIEWMODEL.md
git commit -m "refactor: formalize PomodoroCoordinator for next-session decisions"
git tag phase-3-step-4-done
```

Stop and ask user before 3.5.

---

## STEP 3.5 — Introduce `FocusSessionStore` facade + rewire views

**Goal:** SwiftUI observes a thin facade (`FocusSessionStore`) that composes engine + persistence + recorder + coordinator.

**Action:**
- Create `ForcingFunction/FocusSessionStore.swift` (`@MainActor`, `ObservableObject`).
- Move the SwiftUI-facing published properties and intents into it.
- Update `TimerView` (and other call sites) to observe `FocusSessionStore`.
- `TimerViewModel` should shrink drastically in this step.

**Verify:**
```bash
grep -rn 'TimerViewModel' --include='*.swift' ForcingFunction/ | head -50
# Expect: usage drops; most views use FocusSessionStore.

xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
```

**Commit + tag:**
```bash
git add ForcingFunction/FocusSessionStore.swift ForcingFunction/TimerView.swift ForcingFunction/TimerViewModel.swift PHASE_3_SPLIT_TIMERVIEWMODEL.md
git commit -m "refactor: introduce FocusSessionStore and rewire timer UI"
git tag phase-3-step-5-done
```

Stop and ask user before 3.6.

---

## STEP 3.6 — Protocol-front coordinators (notifications/live activity/bg/widget)

**Goal:** Remove app-code singleton dependencies from the timer surface area by injecting protocol-front “coordinators”.

**Action:**
- Define protocols:
  - `NotificationCoordinator`
  - `LiveActivityCoordinator`
  - `BackgroundTaskCoordinator`
  - `WidgetSyncCoordinator`
- Provide adapters that wrap the existing implementations without behavioral change.
- Inject into `FocusSessionStore` (or composition root).

**Verify:**
```bash
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
```

**Commit + tag:**
```bash
git add ForcingFunction PHASE_3_SPLIT_TIMERVIEWMODEL.md
git commit -m "refactor: inject timer side-effects via coordinator protocols"
git tag phase-3-step-6-done
```

Stop and ask user before 3.7.

---

## STEP 3.7 — Delete or shrink `TimerViewModel` (≤ 200 LOC composer)

**Goal:** The old god object is gone or only composes the new components.

**Action:**
- Delete `TimerViewModel.swift` OR reduce it to a tiny compatibility wrapper (if needed temporarily).
- Grep-sweep to ensure no remaining call sites depend on old internal details.

**Verify:**
```bash
wc -l ForcingFunction/TimerViewModel.swift 2>/dev/null || echo "TimerViewModel.swift deleted"
grep -rn 'class TimerViewModel\\b' --include='*.swift' ForcingFunction/ || true

xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
```

**Commit + tag:**
```bash
git add ForcingFunction PHASE_3_SPLIT_TIMERVIEWMODEL.md
git commit -m "refactor: retire TimerViewModel in favor of focused components"
git tag phase-3-step-7-done
```

Stop and ask user before 3.8.

---

## STEP 3.8 — Fix Live Activity push-token leak (audit noted in roadmap)

**Goal:** Fix the known leak around Live Activity push token handling (as referenced in the roadmap).

**Action:**
- Edit `ForcingFunction/LiveActivityManager.swift` to eliminate the leak without changing feature behavior.

**Verify:**
```bash
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
```

**Commit + tag:**
```bash
git add ForcingFunction/LiveActivityManager.swift PHASE_3_SPLIT_TIMERVIEWMODEL.md
git commit -m "fix: stop Live Activity push-token task leak"
git tag phase-3-step-8-done
```

Stop and ask user before 3.9.

---

## STEP 3.9 — Final verification + tag phase done

```bash
git status
xcodebuild clean build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet

# Tests once at phase end.
xcodebuild test -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'

git tag --list 'phase-3-step-*-done' | wc -l   # expect 10
```

Update STATUS block: all `[x]`, set `PHASE COMPLETE: ✅ yes`, then:

```bash
git add PHASE_3_SPLIT_TIMERVIEWMODEL.md
git commit -m "chore: phase 3 complete — TimerViewModel split"
git tag phase-3-done
```

Stop and tell user Phase 3 is complete. Ask before moving to Phase 4.

---

## END OF PHASE 3

