# PHASE 1 — DECOUPLE THE POMODORO TECHNIQUE FROM THE TIMER ENGINE

> **Goal:** Make the strict 4-work-then-long-break Pomodoro cycle **opt-in**. Default behavior is free-flow focus → short break → focus. Update copy + UI to match.
> **Time:** ~1 week.
> **Risk:** Low–medium (touches TimerView header + Settings layout; protected duration-setting UI is untouched).
> **Pre-req:** Phase 0 complete (`phase-0-done` tag must exist).

---

## 📍 CURRENT STATUS — single source of truth

```
═══════════════════════════════════════════════════════════
  ACTIVE PHASE      : 1 — Decouple Pomodoro
  PHASE STARTED     : 2026-05-08
  LAST COMPLETED    : Step 1.0 — Setup & baseline
  CURRENTLY ON      : (none)
  NEXT TO DO        : Step 1.1 — Drop wasAutoStarted from PomodoroSession
  PHASE COMPLETE    : ❌ no
═══════════════════════════════════════════════════════════

[x] 1.0  Setup & baseline
[ ] 1.1  Drop wasAutoStarted from PomodoroSession
[ ] 1.2  Add strictPomodoroMode flag + gate cycle logic
[ ] 1.3  Humanize notification body
[ ] 1.4  Strip Pomodoro chrome from TimerView header
[ ] 1.5  Gate strict-mode-only Settings behind toggle
[ ] 1.6  Final verification + tag phase done
```

After every step: tick the box, commit, tag, ask user before continuing.

---

## 🤖 NEW SESSION PROTOCOL

1. Read `CLAUDE.md`. Read STATUS block above.
2. Run `git tag --list 'phase-1-*' --sort=-creatordate | head -10` to cross-check.
3. Report status to user. Wait for go-ahead.

---

## 🚫 DO NOT (Phase 1)

- **DO NOT touch the protected duration-setting UI in `TimerView.swift`** — calendar strip, draggable bottom handle on the session block, MM:SS digit vertical drag, ±5 stepper buttons, "now" red line, elapsed-fill. These are sacred.
- Do not rename `SessionType`, `PomodoroSession`, `PomodoroDataStore`, or any `Pomodoro*` symbol. (Naming churn is Phase 2/3.)
- Do not migrate to SwiftData (Phase 2).
- Do not split TimerViewModel (Phase 3).
- Do not edit `ForcingFunction.xcodeproj/project.pbxproj`.
- Do not boot the iOS Simulator app or "manually verify" UI. Trust the build + greps.

---

## 🆘 STOP-AND-ASK if

- File line numbers / structure don't match what's described (codebase drifted).
- A grep returns matches you don't understand.
- Build fails after a step and reverting your edit doesn't fix it.
- The user requests a Phase 1 deviation that conflicts with the protected UI list.

---

## ✂️ FILES IN SCOPE

| File | Why |
|---|---|
| `ForcingFunction/Models.swift` | drop `wasAutoStarted` field |
| `ForcingFunction/TimerViewModel.swift` | drop wasAutoStarted refs; add strict-mode flag; gate `startNextSession()`; update notification copy |
| `ForcingFunction/TimerView.swift` | strip header "Pomodoro N." title, drop 1/4 badge + segment bar (NOT the duration UI) |
| `ForcingFunction/SettingsView.swift` | gate strict-mode-only sections behind toggle |
| `PHASE_1_DECOUPLE_POMODORO.md` | status block updates |

Anything else: out of scope. Stop and ask.

---

## STEP 1.0 — Setup & baseline

```bash
git status                                 # working tree must be clean
git checkout -b refactor/phase-1-decouple
git tag phase-1-baseline
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
# exit 0 required
```

Update STATUS block (`[ ] 1.0` → `[x] 1.0`, set PHASE STARTED date, set NEXT TO DO = 1.1), then:
```bash
git add PHASE_1_DECOUPLE_POMODORO.md
git commit -m "chore: phase-1 baseline"
git tag phase-1-step-0-done
```
Ask user before 1.1.

---

## STEP 1.1 — Drop `wasAutoStarted` from `PomodoroSession`

Field is set, never read. Dead Pomodoro-cycle artifact.

**Verify dead:**
```bash
grep -rn 'wasAutoStarted\|isAutoStartingNext' --include='*.swift' .
# Expect: declaration in Models.swift; ~3 setters in TimerViewModel.swift. Zero reads.
# If reads exist anywhere: STOP, show user.
```

**Edit `Models.swift` — `struct PomodoroSession`:**
- Delete the `let wasAutoStarted: Bool` field declaration.
- Delete the init parameter `wasAutoStarted: Bool = false,` (mind trailing commas).
- Delete `self.wasAutoStarted = wasAutoStarted` in init body.

**Edit `TimerViewModel.swift`:**
- Delete `private var isAutoStartingNext = false` (around the private properties block).
- In the `PomodoroSession(...)` constructor inside `startTimer()`: delete the `wasAutoStarted: isAutoStartingNext,` argument line.
- Delete the line `isAutoStartingNext = false // Reset flag after use`.
- In `startNextSession()`: delete `isAutoStartingNext = true`.

**Verify after:**
```bash
grep -rn 'wasAutoStarted\|isAutoStartingNext' --include='*.swift' .
# Expect: empty.
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
```

**Commit + tag:**
```bash
git add ForcingFunction/Models.swift ForcingFunction/TimerViewModel.swift PHASE_1_DECOUPLE_POMODORO.md
git commit -m "refactor: drop write-only wasAutoStarted from PomodoroSession"
git tag phase-1-step-1-done
```

Ask user before 1.2.

---

## STEP 1.2 — Add `strictPomodoroMode` toggle + gate cycle in `startNextSession()`

Default OFF (free-flow). When OFF: every break after work is a short break, no long break, no 4-cycle counter.

**Edit `TimerViewModel.swift`:**

In the `// MARK: - Settings (using @AppStorage)` block, add:
```swift
@AppStorage("strictPomodoroMode") var strictPomodoroMode: Bool = false
```

Replace the entire `func startNextSession()` body with:
```swift
func startNextSession() {
    if currentSessionType == .work {
        if strictPomodoroMode {
            completedPomodoros = dataStore.getCompletedPomodorosCount()
            if completedPomodoros >= pomodorosBeforeLongBreak {
                currentSessionType = .longBreak
                selectedMinutes = longBreakMinutes
                completedPomodoros = 0
            } else {
                currentSessionType = .shortBreak
                selectedMinutes = shortBreakMinutes
            }
        } else {
            // Free-flow: every post-work break is a short break.
            currentSessionType = .shortBreak
            selectedMinutes = shortBreakMinutes
        }
    } else {
        currentSessionType = .work
        selectedMinutes = pomodoroMinutes
    }

    remainingSeconds = Int(selectedMinutes * 60)
    pausedSeconds = remainingSeconds
    timerState = .idle
    updateIdleTimerForSession()

    if autoStartNext {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.startTimer() }
    }
}
```

Note: this body intentionally has no `isAutoStartingNext = true` line (removed in 1.1).

**Verify:**
```bash
grep -n 'strictPomodoroMode' ForcingFunction/TimerViewModel.swift   # ≥ 2 matches
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
```

**Commit + tag:**
```bash
git add ForcingFunction/TimerViewModel.swift PHASE_1_DECOUPLE_POMODORO.md
git commit -m "feat: free-flow default; strict 4-cycle Pomodoro is opt-in"
git tag phase-1-step-2-done
```

Ask user before 1.3.

---

## STEP 1.3 — Humanize notification body

Current copy: `"Your \(currentSessionType.displayName) session has finished!"` → reads as "Your Work session has finished!" — clunky.

**Edit `TimerViewModel.swift` — `scheduleNotification()`:**

Replace:
```swift
content.title = "Session Complete"
content.body = "Your \(currentSessionType.displayName) session has finished!"
```
with:
```swift
content.title = "Session complete"
content.body = currentSessionType == .work
    ? "Focus session complete. Take a break."
    : "Break over. Ready for the next session?"
```

**Verify:**
```bash
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
```

**Commit + tag:**
```bash
git add ForcingFunction/TimerViewModel.swift PHASE_1_DECOUPLE_POMODORO.md
git commit -m "polish: humanize completion notification copy"
git tag phase-1-step-3-done
```

Ask user before 1.4.

---

## STEP 1.4 — Strip Pomodoro chrome from TimerView header

⚠️ Touch ONLY: the `titleText` computed property, the `pomodoroIndex` computed property, the `Text("\(pomodoroIndex)/4")` capsule badge inside `timerCard`, and the `segmentBar` view + its usage. **DO NOT** touch the calendar strip, the timer card's MM:SS digits, the digit-drag gesture, the ±5 stepper buttons, or the bottom resize handle.

**Edit `TimerView.swift`:**

1. **Add project store observation.** Below `@ObservedObject var viewModel: TimerViewModel`, add:
   ```swift
   @ObservedObject private var projectStore = ProjectStore.shared
   ```

2. **Replace the entire `titleText` computed property** with:
   ```swift
   private var titleText: String {
       switch viewModel.currentSessionType {
       case .shortBreak: return "Short break"
       case .longBreak:  return "Long break"
       case .work:
           if let id = UUID(uuidString: viewModel.setupProjectId),
              let p = projectStore.project(id: id) {
               return p.name
           }
           return "Focus"
       }
   }
   ```

3. **Delete the `pomodoroIndex` computed property** entirely.

4. **In `timerCard`**, find the `HStack { Text("REMAINING").hcMonoLabel(size: 9); Spacer(); Text("\(pomodoroIndex)/4")...` block. **Delete the `Text("\(pomodoroIndex)/4")...` capsule** (the 1/4 badge). Keep the "REMAINING" label and the `Spacer()`.

5. **In `timerCard`**, delete the line `segmentBar.padding(.top, 10)`.

6. **Delete the `segmentBar` computed property** entirely.

**Verify:**
```bash
grep -n 'pomodoroIndex\|segmentBar' ForcingFunction/TimerView.swift
# Expect: empty.
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
```

**Commit + tag:**
```bash
git add ForcingFunction/TimerView.swift PHASE_1_DECOUPLE_POMODORO.md
git commit -m "ui: drop Pomodoro Technique chrome from Focus header"
git tag phase-1-step-4-done
```

Ask user before 1.5.

---

## STEP 1.5 — Gate strict-mode-only Settings behind the toggle

When `strictPomodoroMode == false`, hide "Session Durations" + "Pomodoro Cycle" sections (they only matter under strict mode). Show a "Pomodoro Technique" toggle section instead.

**Edit `SettingsView.swift`:**

**A.** Below the existing `Section(header: sectionHeader("Appearance"))` block, **insert a new section**:
```swift
Section(header: sectionHeader("Pomodoro Technique")) {
    Toggle(isOn: $viewModel.strictPomodoroMode) {
        VStack(alignment: .leading, spacing: 2) {
            Text("Strict mode")
                .font(HC.text(16))
                .foregroundStyle(HC.ink)
            Text("Enforces 4-pomodoro cycle with long breaks.")
                .font(HC.text(12))
                .foregroundStyle(HC.muted)
        }
    }
    .tint(HC.red)
}
.listRowBackground(HC.card)
.listRowSeparatorTint(HC.line)
```

**B.** Wrap the existing two sections — `Section(header: sectionHeader("Session Durations"))` AND the immediately-following `Section(header: sectionHeader("Pomodoro Cycle"))` — inside a single `if viewModel.strictPomodoroMode { … }` block. Keep all their inner contents identical.

**Verify:**
```bash
grep -n 'strictPomodoroMode' ForcingFunction/SettingsView.swift   # ≥ 2 matches
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
```

**Commit + tag:**
```bash
git add ForcingFunction/SettingsView.swift PHASE_1_DECOUPLE_POMODORO.md
git commit -m "ui: hide strict-Pomodoro settings behind opt-in toggle"
git tag phase-1-step-5-done
```

Ask user before 1.6.

---

## STEP 1.6 — Final verification + tag phase done

```bash
git status                                            # clean
xcodebuild clean build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet

# Tests once at phase end.
xcodebuild test -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
# If "iPhone 15" unavailable: xcrun simctl list devices available | grep iPhone
# and substitute an available name.

# Sanity sweeps.
grep -rn 'wasAutoStarted\|isAutoStartingNext\|pomodoroIndex\|segmentBar' --include='*.swift' .
# expect: empty

git log phase-1-baseline..HEAD --oneline | wc -l       # expect ~7
```

Tick all step boxes `[x]`, set `PHASE COMPLETE: ✅ yes`. Then:
```bash
git add PHASE_1_DECOUPLE_POMODORO.md
git commit -m "chore: phase 1 complete — Pomodoro Technique decoupled"
git tag phase-1-done
```

Tell user:
> ✅ Phase 1 done. Free-flow focus is now the default; strict 4-cycle Pomodoro is opt-in via Settings → Pomodoro Technique → Strict mode. Header shows project name (or "Focus") instead of "Pomodoro N." Notification copy is humanized. All tests green. Ready for Phase 2 (SwiftData persistence rebuild) whenever you say.

---

## ✅ ACCEPTANCE CRITERIA

- [ ] All 7 step boxes `[x]`.
- [ ] `phase-1-done` tag exists.
- [ ] `xcodebuild clean build` exits 0.
- [ ] `xcodebuild test` runs, all tests green.
- [ ] Sanity grep returns empty: `wasAutoStarted`, `isAutoStartingNext`, `pomodoroIndex`, `segmentBar`.
- [ ] No edits to: `project.pbxproj`, `HCDesign.swift`, the protected duration-setting UI in `TimerView.swift`.

---

## 🔄 ROLLBACK

```bash
# One step back:
git reset --hard phase-1-step-{N-1}-done

# Whole phase:
git checkout main
git branch -D refactor/phase-1-decouple
git tag -d phase-1-baseline phase-1-done
git tag --list 'phase-1-step-*-done' | xargs -r git tag -d
```

---

## END OF PHASE 1
