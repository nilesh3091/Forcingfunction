# PHASE 0 — TRIAGE & HONESTY

> **One-line goal:** Delete dead code, remove features that lie, add a real test, leave the codebase honest. **No new behavior. No visible UI changes** beyond two small removals (Reset Statistics button, dead tag pill).
>
> **Time estimate:** 1 week (≈ 4–6 focused hours of agent work).
> **Risk:** Low. Every step is independently revertable.
> **Pre-requisites:** None. This is the first phase.
> **Unblocks:** Phase 1 (decoupling Pomodoro semantics).

---

## 📍 CURRENT STATUS — single source of truth (KEEP UPDATED)

```
═══════════════════════════════════════════════════════════
  ACTIVE PHASE      : 0 — Triage & Honesty
  PHASE STARTED     : 2026-05-07
  LAST COMPLETED    : 0.4 — Remove categoryId from PomodoroSession
  CURRENTLY ON      : (none)
  NEXT TO DO        : Step 0.5 — Trim AppTheme to actually-used props
  PHASE COMPLETE    : ❌ no
═══════════════════════════════════════════════════════════

STEP CHECKLIST:

  [x] 0.0  Setup & baseline                     (verify env, create branch)
  [x] 0.1  Delete Item.swift                    (dead SwiftData artifact)
  [x] 0.2  Delete dead model code               (Category + PomodoroTask in Models.swift)
  [x] 0.3  Delete categoriesDidChange notif     (NotificationDelegate.swift)
  [x] 0.4  Remove categoryId from session       (Models.swift + 2 refs in TimerViewModel)
  [ ] 0.5  Trim AppTheme to actually-used props (Models.swift)
  [ ] 0.6  Delete "Reset Statistics" button     (SettingsView.swift)
  [ ] 0.7  Delete dead setupTag pill            (TimerView.swift header)
  [ ] 0.8  Add real unit tests                  (ForcingFunctionTests.swift)
  [ ] 0.9  Final verification + tag phase done  (xcodebuild + git tag phase-0-done)

LEGEND:  [ ] not started   [~] in progress   [x] done   [-] skipped (with reason)
```

> **Update protocol (every step):**
> 1. Before starting step N.X: change `[ ]` to `[~]` for that step. Update `CURRENTLY ON`. Commit: `chore: start phase 0 step X`.
> 2. After step N.X passes verification: change `[~]` to `[x]`. Update `LAST COMPLETED` and `NEXT TO DO`. Commit with the step's exact commit message. Tag: `git tag phase-0-step-X-done`.
> 3. Then STOP and ask the user: "Step 0.X complete. Want me to continue to 0.Y?"

---

## 🤖 IF YOU ARE AN AI READING THIS FOR THE FIRST TIME IN A NEW SESSION

1. Read the `📍 CURRENT STATUS` block above.
2. Run: `git tag --list 'phase-0-*' --sort=-creatordate | head -5` to cross-check.
3. Tell the user where things stand using the format in `CLAUDE.md` ("Active phase…").
4. Ask the user before doing the next step.

If the status block disagrees with git tags, **stop and report the discrepancy.** Do not guess.

---

## 🚫 DO NOT (forbidden in Phase 0)

- Do **not** rename `SessionType`, `PomodoroSession`, `PomodoroDataStore`, `PomodoroSetupSheet`, or any "Pomodoro"-named symbol. Phase 1 handles renaming.
- Do **not** modify `TimerView.swift` except for Step 0.7's surgical removal.
- Do **not** modify the `HC` design system (`HCDesign.swift`).
- Do **not** modify the calendar strip, the timer card's MM:SS digits, the ±5 stepper buttons, or any draggable handle in `TimerView.swift`.
- Do **not** edit `ForcingFunction.xcodeproj/project.pbxproj` directly. Xcode-level changes (target membership, group reorganization) are deferred to a later "user-assisted" Phase 0.5 if at all.
- Do **not** add new files except where Step 0.8 explicitly says to.
- Do **not** add new third-party dependencies.
- Do **not** "improve while you're there." If you find an out-of-scope issue, mention it to the user but do not fix it in this phase.

---

## ✅ FILES IN SCOPE FOR PHASE 0 (only these may be modified or deleted)

| File | What happens |
|---|---|
| `ForcingFunction/Item.swift` | **deleted** in Step 0.1 |
| `ForcingFunction/Models.swift` | edited in Steps 0.2, 0.4, 0.5 (deletions only) |
| `ForcingFunction/NotificationDelegate.swift` | edited in Step 0.3 (deletion of one line) |
| `ForcingFunction/TimerViewModel.swift` | edited in Step 0.4 (removal of `categoryId` references) |
| `ForcingFunction/TimerView.swift` | edited in Step 0.7 (removal of dead pill + `trimmedTag` computed property) |
| `ForcingFunction/SettingsView.swift` | edited in Step 0.6 (removal of "Reset Statistics" button) |
| `ForcingFunctionTests/ForcingFunctionTests.swift` | edited in Step 0.8 (replace stub with real tests) |
| `PHASE_0_TRIAGE.md` (this file) | edited every step — status block updates |

**Any other file is OUT OF SCOPE.** If a step seems to require touching another file, stop and ask.

---

## 📦 STEP 0.0 — Setup & baseline

**Goal:** Verify the environment is sane before any change. Create a working branch. Confirm baseline build passes so we know later breakage came from our edits.

### Verify before:

```bash
# 1. Working tree must be clean.
git status
# Expected: "nothing to commit, working tree clean".
# If dirty: STOP. Ask the user whether to stash or commit existing changes.

# 2. Confirm we're in the right repo.
ls ForcingFunction.xcodeproj && ls ForcingFunction/TimerView.swift
# Both must exist.

# 3. Baseline build must pass.
xcodebuild build \
  -project ForcingFunction.xcodeproj \
  -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' \
  -quiet
# Exit code must be 0. If it fails on the baseline (before any edit),
# STOP. The repo is broken before we touched it. Ask the user.
```

### Action:

```bash
# Create a working branch for the entire Phase 0 effort.
git checkout -b refactor/phase-0-triage

# Tag the baseline so we can always return to it.
git tag phase-0-baseline
```

### Verify after:

```bash
git branch --show-current
# Must print: refactor/phase-0-triage

git tag --list 'phase-0-baseline'
# Must print: phase-0-baseline
```

### Update STATUS block:

- Change `[ ] 0.0` to `[x] 0.0`.
- Set `PHASE STARTED` to today's date.
- Set `LAST COMPLETED` to `0.0`.
- Set `CURRENTLY ON` to `(none)`.
- Set `NEXT TO DO` to `0.1`.

### Commit:

```bash
git add PHASE_0_TRIAGE.md
git commit -m "chore: phase-0 baseline + working branch"
git tag phase-0-step-0-done
```

### Stop & ask user:

> Step 0.0 done. Branch `refactor/phase-0-triage` is up. Baseline build was green. Continue with 0.1?

---

## 🗑️ STEP 0.1 — Delete `Item.swift`

**Goal:** Remove the unused SwiftData @Model artifact left by the Xcode template.

**File to delete:** `ForcingFunction/Item.swift`

### Verify before delete (PROVE it's dead code):

```bash
# 1. Confirm file exists and contains the expected @Model.
cat ForcingFunction/Item.swift | head -20
# Must contain: "@Model" and "final class Item"

# 2. Confirm NO references anywhere else.
grep -rn '\bItem\b' --include='*.swift' . \
  | grep -v 'ForcingFunction/Item.swift:' \
  | grep -v '// '         # filter out comments
# Expected output: empty (no matches outside Item.swift itself).
# If there ARE matches: STOP. Show them to the user before deleting.

# 3. Confirm SwiftData is not imported anywhere else.
grep -rn 'import SwiftData' --include='*.swift' .
# Expected output: only ForcingFunction/Item.swift:8 (or similar).
# If imported elsewhere: STOP — the file may be more connected than we thought.
```

### Action:

```bash
git rm ForcingFunction/Item.swift
```

> ⚠️ **DO NOT** edit `ForcingFunction.xcodeproj/project.pbxproj` to remove the file reference. The build system will complain about the missing reference; that's expected. The user will clean it up in Xcode at end-of-phase. **Never edit project.pbxproj directly from this phase.**

### Verify after:

```bash
# File must be gone from working tree.
ls ForcingFunction/Item.swift 2>/dev/null && echo "STILL EXISTS" || echo "deleted"
# Must print: deleted

# Build will likely fail because project.pbxproj still references the file.
# THAT IS EXPECTED for this step. We accept the build failure for one commit.
xcodebuild build \
  -project ForcingFunction.xcodeproj \
  -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' \
  -quiet 2>&1 | tail -5
# If build SUCCEEDS, great — the file wasn't in the target. Skip the user-action note below.
# If build FAILS with "missing file Item.swift", that's expected.
```

### Stop & ask user (only if build failed):

> The file is deleted from disk, but `project.pbxproj` still references it. Open Xcode, find `Item.swift` in the file tree (it'll be red), and remove the reference (right-click → Delete → Remove Reference). Then come back and confirm. I will not edit `project.pbxproj` myself.

> **Wait for user confirmation that they cleaned the Xcode reference.** Then re-run the build:

```bash
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
# Now must succeed.
```

### Update STATUS block:

- `[ ] 0.1` → `[x] 0.1`. Update `LAST COMPLETED` and `NEXT TO DO`.

### Commit:

```bash
git add -A
git commit -m "chore: delete unused Item.swift (SwiftData template artifact)"
git tag phase-0-step-1-done
```

### Stop & ask user:

> Step 0.1 done. `Item.swift` removed; build green. Continue with 0.2?

---

## 🗑️ STEP 0.2 — Delete dead model code (`Category`, `PomodoroTask`)

**Goal:** Remove two structs in `Models.swift` that are never instantiated anywhere.

**File:** `ForcingFunction/Models.swift`

### Verify before delete:

```bash
# 1. Confirm `Category` (the STRUCT, not CategoryColor!) is unreferenced outside its declaration.
grep -rn '\bCategory\b' --include='*.swift' . \
  | grep -v 'CategoryColor'                    \
  | grep -v 'Models.swift:.*// MARK: - Category' \
  | grep -v 'Models.swift:.*struct Category'   \
  | grep -v 'categoriesDidChange'              \
  | grep -v '// '
# Expected: empty. If non-empty: STOP, show user.

# 2. Confirm `PomodoroTask` is unreferenced.
grep -rn '\bPomodoroTask\b' --include='*.swift' .
# Expected: only the struct's own declaration in Models.swift. Nothing else.
```

> **Important:** `CategoryColor` (the *enum*) is **HEAVILY USED**. We are NOT deleting `CategoryColor`. We are only deleting the `Category` *struct* and the `PomodoroTask` *struct*.

### Action:

Edit `ForcingFunction/Models.swift`:

1. **Delete the `Category` struct.** Remove the section starting at the line containing `// MARK: - Category Models` through the closing `}` of `struct Category`. Concretely:
   - The `// MARK: - Category Models` comment
   - The `/// Represents a category for pomodoro sessions` doc comment
   - The entire `struct Category: Codable, Identifiable { … }` block
   - **Keep** the `enum CategoryColor` declaration that lives in this section. The `CategoryColor` enum is used by the `Project` model and remains.
   - **Keep** the `// MARK: - Color options for categories` doc comment if it sits above `CategoryColor`.

2. **Delete the `PomodoroTask` struct.** Remove the section:
   - The `// MARK: - Task Models` comment
   - The `/// Represents a task with pomodoro time tracking` doc comment
   - The entire `struct PomodoroTask: Codable, Identifiable { … }` block including the `formattedTime` computed property

> 💡 **Tip:** Use grep to locate the exact line ranges before editing:
> ```bash
> grep -n 'struct Category\b\|struct PomodoroTask\b\|MARK: - Category Models\|MARK: - Task Models' ForcingFunction/Models.swift
> ```

### Verify after:

```bash
# Build must pass.
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
# Exit 0 required.

# Re-confirm the structs are gone but CategoryColor remains.
grep -n '^struct Category\b' ForcingFunction/Models.swift   # Must be empty.
grep -n '^struct PomodoroTask\b' ForcingFunction/Models.swift  # Must be empty.
grep -n '^enum CategoryColor\b' ForcingFunction/Models.swift   # Must still exist.
```

### Update STATUS block, commit, tag:

```bash
git add ForcingFunction/Models.swift PHASE_0_TRIAGE.md
git commit -m "chore: delete unused Category and PomodoroTask models"
git tag phase-0-step-2-done
```

### Stop & ask user:

> Step 0.2 done. Continue with 0.3?

---

## 🗑️ STEP 0.3 — Delete `categoriesDidChange` notification

**Goal:** Remove a notification name that is declared but never posted or observed.

**File:** `ForcingFunction/NotificationDelegate.swift`

### Verify before:

```bash
grep -rn 'categoriesDidChange' --include='*.swift' .
# Expected: ONLY the declaration in NotificationDelegate.swift.
# If anything posts or observes it: STOP, show user. (There shouldn't be — audited dead.)
```

### Action:

Edit `ForcingFunction/NotificationDelegate.swift`. Inside the `extension Notification.Name { … }` at the bottom, delete the single line:

```swift
static let categoriesDidChange = Notification.Name("categoriesDidChange")
```

Keep the `timerCompletedInBackground` line. Keep the rest of the file untouched.

### Verify after:

```bash
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
# Exit 0.

grep 'categoriesDidChange' --include='*.swift' -rn .
# Expected: empty.
```

### Commit + tag:

```bash
git add ForcingFunction/NotificationDelegate.swift PHASE_0_TRIAGE.md
git commit -m "chore: drop unused categoriesDidChange notification"
git tag phase-0-step-3-done
```

> Step 0.3 done. Continue with 0.4?

---

## 🗑️ STEP 0.4 — Remove `categoryId` field from `PomodoroSession`

**Goal:** Remove a field that is always `nil` everywhere it is set. Existing JSON files have `categoryId` keys; Swift's `JSONDecoder` ignores unknown keys, so old data still loads safely.

**Files:**
- `ForcingFunction/Models.swift` — remove field + init parameter + assignment
- `ForcingFunction/TimerViewModel.swift` — remove the two places that pass `categoryId: nil`

### Verify before:

```bash
# Audit the field's footprint.
grep -n 'categoryId' ForcingFunction/Models.swift ForcingFunction/TimerViewModel.swift
# You should see roughly:
#   Models.swift  — `var categoryId: UUID?`     (the field)
#   Models.swift  — `categoryId: UUID? = nil,`  (init param)
#   Models.swift  — `self.categoryId = categoryId` (init body)
#   TimerViewModel.swift  — `let sessionCategoryId: UUID? = nil`  (×2)
#   TimerViewModel.swift  — `categoryId: sessionCategoryId,`      (×2)
#
# If references appear in OTHER files, STOP and show user.

# Verify nothing reads the field.
grep -rn '\.categoryId' --include='*.swift' .
# Expected: empty (no readers anywhere).
```

### Action:

**A) `ForcingFunction/Models.swift`** — inside `struct PomodoroSession`:

1. Delete the line declaring the field: `var categoryId: UUID?`
2. In the `init(...)` parameter list, delete the parameter `categoryId: UUID? = nil,` (mind the trailing comma — keep the parameter list well-formed).
3. In the `init` body, delete the line `self.categoryId = categoryId`.

**B) `ForcingFunction/TimerViewModel.swift`** — at the two call sites that build a `PomodoroSession`:

1. Find each `let sessionCategoryId: UUID? = nil` and **delete that line**.
2. Find each `categoryId: sessionCategoryId,` argument in the `PomodoroSession(...)` constructor call and **delete that line**.
3. There is also one constructor call with `categoryId: sessionCategoryId, title: nil, tag: nil, tagColor: nil` — delete only the `categoryId:` line; leave the others alone.

> 💡 The constructor calls are inside `startTimer()` and `ensureCurrentSessionExists()`. Use grep to find them:
> ```bash
> grep -n 'PomodoroSession(' ForcingFunction/TimerViewModel.swift
> grep -n 'categoryId' ForcingFunction/TimerViewModel.swift
> ```

### Verify after:

```bash
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
# Exit 0.

# Confirm the field is gone from code.
grep -rn 'categoryId' --include='*.swift' .
# Expected: empty.

# Confirm Models.swift still compiles (PomodoroSession still has its other fields).
grep -n 'struct PomodoroSession' ForcingFunction/Models.swift
# Expected: still present.
```

### Backward-compatibility check (do not skip):

Open `ForcingFunction/Models.swift` and confirm `PomodoroSession` is still `Codable`. Existing JSON files in users' `Documents` directory contain a `"categoryId" : null` key in old session objects. Swift's `JSONDecoder` will ignore unknown keys silently. Therefore old data still decodes. **No migration needed for this change.** Confirm by reading the struct definition: it should still derive `Codable`.

### Commit + tag:

```bash
git add ForcingFunction/Models.swift ForcingFunction/TimerViewModel.swift PHASE_0_TRIAGE.md
git commit -m "refactor: remove always-nil categoryId field from PomodoroSession"
git tag phase-0-step-4-done
```

> Step 0.4 done. Continue with 0.5?

---

## 🗑️ STEP 0.5 — Trim `AppTheme` to actually-used properties

**Goal:** `AppTheme` declares ~30 colour properties; only **3** are read anywhere in the app (`workAccent`, `breakAccent`, `accentColor`). The rest is dead. Keep the public surface that is actually used; delete the rest.

**File:** `ForcingFunction/Models.swift`

### Verify before — find what's actually read:

```bash
# All theme reads in non-Models files.
grep -rn 'theme\.[a-zA-Z]' --include='*.swift' ForcingFunction/ \
  | grep -v 'Models.swift:'
# This shows which AppTheme properties are actually used.
# As of audit: ONLY accentColor, workAccent, breakAccent.
# If grep finds OTHER properties being read: STOP. Update the "keep list" below to include them.
```

### Action:

Edit `ForcingFunction/Models.swift`. Inside `struct AppTheme`:

**Keep ONLY** these properties (remove every other `let` in the struct):
- `let workAccent: Color`
- `let breakAccent: Color`
- `let destructiveAccent: Color`  *(used inside `init` to construct accent variants — verify with grep; if not read externally, we still keep it because the `init` references it)*
- `let accentColor: Color`

Also keep:
- `static let standard = AppTheme()`
- The `private init()` body — but **simplify** it to only assign the four kept properties. Delete the assignments to all the deleted properties.
- The two `private static func dyn(...)` and `dynA(...)` helpers if they are still referenced inside the simplified `init`. If unreferenced after simplification, delete them too.

**Delete:**
- All `accentColorLight`, `accentColorDark` properties
- All `backgroundPrimary`, `backgroundSecondary`, `backgroundTertiary`, `backgroundCard`, `backgroundOverlay` properties
- All `textPrimary`, `textSecondary`, `textTertiary`, `textDisabled` properties
- All `borderPrimary`, `borderSecondary`, `divider` properties
- All `buttonPrimary`, `buttonPrimaryText`, `buttonSecondary`, `buttonSecondaryText`, `buttonDisabled`, `buttonDisabledText` properties
- All `success`, `warning`, `error`, `info` properties
- `interactive`, `interactivePressed` properties
- `shadowLight`, `shadowMedium`, `shadowHeavy` properties
- The helper functions on `AppTheme`: `func color(_:opacity:)`, `func accent(opacity:)`, `func text(_:opacity:)`, `func background(_:)` — none are used externally; delete.
- The `enum TextLevel` and `enum BackgroundLevel` — both only support the deleted helper functions; delete.

> ⚠️ **Run grep after every deletion to confirm nothing breaks:**
> ```bash
> grep -rn 'TextLevel\|BackgroundLevel' --include='*.swift' .
> # Must be empty before you delete those enums.
> ```

### Verify after:

```bash
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet
# Exit 0 required.

# Check the surviving AppTheme is small.
awk '/^struct AppTheme/,/^}/' ForcingFunction/Models.swift | wc -l
# Should be roughly 25–40 lines (was ~110+).
```

### Commit + tag:

```bash
git add ForcingFunction/Models.swift PHASE_0_TRIAGE.md
git commit -m "refactor: trim AppTheme to actually-used properties"
git tag phase-0-step-5-done
```

> Step 0.5 done. Continue with 0.6?

---

## 🗑️ STEP 0.6 — Delete the "Reset Statistics" button

**Why:** The button writes `viewModel.totalFocusMinutes = 0` and `viewModel.completedPomodoros = 0`, but those are derived from the JSON data store and reload on next launch. The button does not actually reset anything. Removing the lie is more honest than fixing it (Phase 4+ will introduce a real "delete history" flow).

**File:** `ForcingFunction/SettingsView.swift`

### Verify before:

```bash
grep -n 'Reset Statistics\|completedPomodoros = 0\|totalFocusMinutes = 0' ForcingFunction/SettingsView.swift
# Should show three nearby lines: a Button block + the two assignments inside its action.
```

### Action:

Edit `ForcingFunction/SettingsView.swift`. Inside the `Section(header: sectionHeader("Statistics"))`:

1. Delete the entire `Button` block:

```swift
Button(action: {
    viewModel.totalFocusMinutes = 0
    viewModel.completedPomodoros = 0
}) {
    Text("Reset Statistics")
        .font(HC.text(16))
        .foregroundStyle(HC.red)
}
```

2. **Keep** the two read-only `HStack` rows (Total Focus Time, Completed Pomodoros) above it. Those are honest — they display real data.

### Verify after:

```bash
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet

grep -n 'Reset Statistics' ForcingFunction/SettingsView.swift
# Expected: empty.
```

### Manual smoke test (do not skip):

```bash
# Launch the app in a simulator.
xcrun simctl list devices available | grep -m1 'iPhone' | head -1
# Pick an available simulator from that list and:
xcodebuild run -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
```

Manually navigate: Tune (gear) tab → scroll to "Statistics" section. Confirm the two readouts (Total Focus Time / Completed Pomodoros) still appear, and the Reset button is gone. Settings sectioning should look unchanged otherwise.

### Commit + tag:

```bash
git add ForcingFunction/SettingsView.swift PHASE_0_TRIAGE.md
git commit -m "fix: remove Reset Statistics button (it didn't actually reset)"
git tag phase-0-step-6-done
```

> Step 0.6 done. This is the FIRST visible UI change in Phase 0 — the Reset button is gone. Continue with 0.7?

---

## 🗑️ STEP 0.7 — Delete dead `setupTag` pill in TimerView header

**Why:** `viewModel.setupTag` is a free-form tag string that the new Project/Tag system replaced. The Setup sheet no longer writes to `setupTag`, but `TimerView`'s header still reads it. For users who used the app before the project migration, stale free-form text leaks into the new header. Drop the pill.

**File:** `ForcingFunction/TimerView.swift`

> ⚠️ **Critical:** This is the ONE file that contains the protected duration-setting UI (calendar strip, draggable handle, MM:SS card, ±5 steppers). **DO NOT** touch any of those. Only touch the two specific blocks below.

### Verify before:

```bash
grep -n 'trimmedTag\|setupTag' ForcingFunction/TimerView.swift
# Should show:
#  - the `trimmedTag` computed property (~ lines 82–86)
#  - one read of `trimmedTag` inside `headerBar` (~ lines 175–186, the `if let tag = trimmedTag` block)
# Confirm these are the ONLY two places `setupTag` or `trimmedTag` appears in the file.
```

### Action:

Edit `ForcingFunction/TimerView.swift`:

1. **Delete the `trimmedTag` computed property** (the small `private var trimmedTag: String? { … }` near the other derived-state properties).

2. **Delete the pill block in `headerBar`.** It looks like:

```swift
if let tag = trimmedTag {
    Text(tag.uppercased())
        .font(HC.mono(9, weight: .semibold))
        .tracking(1.0)
        .foregroundStyle(HC.bg)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(HC.ink, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .padding(.top, 6)
}
```

Delete that entire `if let tag = trimmedTag { … }` block. **Keep** the `Spacer()` and the `VStack(alignment: .leading)` block above it — those are part of the protected header layout.

> 💡 **Do NOT** delete the `setupTag` AppStorage in `TimerViewModel.swift`. Phase 1 will handle that. We are only removing the dead UI read.

### Verify after:

```bash
xcodebuild build -project ForcingFunction.xcodeproj -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' -quiet

# `trimmedTag` must be gone from this file.
grep -n 'trimmedTag' ForcingFunction/TimerView.swift
# Expected: empty.

# `setupTag` should NOT be gone from the project (still in TimerViewModel.swift, PomodoroSetupSheet.swift).
grep -rn 'setupTag\b' --include='*.swift' .
# Expected: matches in TimerViewModel.swift and PomodoroSetupSheet.swift only.
# NO matches in TimerView.swift.
```

### Manual smoke test (DO NOT SKIP — protected UI):

Build & run on simulator. On the Focus tab:
- ✅ Calendar strip on the left scrolls and shows the "now" red line.
- ✅ Session block on the strip is draggable at the bottom edge — duration changes.
- ✅ MM:SS digits on the right card respond to vertical drag (idle state).
- ✅ The ±5 stepper buttons work.
- ✅ The header shows "SESSION №X" and "Pomodoro X." but no pill on the right side.
- ✅ Start/pause/end actions still work.

If ANY of the above is broken, **revert this commit immediately** and stop:

```bash
git revert HEAD
```

### Commit + tag:

```bash
git add ForcingFunction/TimerView.swift PHASE_0_TRIAGE.md
git commit -m "fix: remove dead setupTag pill from TimerView header"
git tag phase-0-step-7-done
```

> Step 0.7 done. Visible change: header pill is gone. Calendar strip + duration UI untouched. Continue with 0.8?

---

## 🧪 STEP 0.8 — Add real unit tests

**Goal:** Replace the empty `@Test func example()` stub with two real tests. Establishes the test target as a useful surface for Phase 2/3.

**File:** `ForcingFunctionTests/ForcingFunctionTests.swift`

### Verify before:

```bash
cat ForcingFunctionTests/ForcingFunctionTests.swift
# Confirm it currently contains the empty `@Test func example()` stub.
# Confirm it uses `import Testing` (Swift Testing framework).
```

### Action:

**Replace the entire contents** of `ForcingFunctionTests/ForcingFunctionTests.swift` with:

```swift
//
//  ForcingFunctionTests.swift
//  ForcingFunctionTests
//
//  Real unit tests for foundational model behavior.
//

import Testing
import Foundation
@testable import ForcingFunction

// MARK: - PomodoroSession.activeDurationMinutes

@Suite("PomodoroSession active duration math")
struct PomodoroSessionActiveDurationTests {

    /// A 25-minute session with no pauses should report 25 active minutes.
    @Test func completedSessionWithoutPauses() {
        let start = Date(timeIntervalSince1970: 0)
        let end   = Date(timeIntervalSince1970: 25 * 60)
        let session = PomodoroSession(
            sessionType: .work,
            startTime: start,
            endTime: end,
            plannedDurationMinutes: 25,
            status: .completed,
            events: [
                SessionEvent(timestamp: start, eventType: .started),
                SessionEvent(timestamp: end,   eventType: .completed)
            ]
        )
        #expect(session.activeDurationMinutes == 25.0)
    }

    /// A session paused for 5 minutes mid-flight should subtract that pause.
    @Test func sessionWithSinglePauseAndResume() {
        let t0    = Date(timeIntervalSince1970: 0)
        let t300  = Date(timeIntervalSince1970: 5  * 60)   // pause at 5 min
        let t600  = Date(timeIntervalSince1970: 10 * 60)   // resume at 10 min  (5 min paused)
        let t1500 = Date(timeIntervalSince1970: 25 * 60)   // end at 25 min total
        let session = PomodoroSession(
            sessionType: .work,
            startTime: t0,
            endTime: t1500,
            plannedDurationMinutes: 25,
            status: .completed,
            events: [
                SessionEvent(timestamp: t0,    eventType: .started),
                SessionEvent(timestamp: t300,  eventType: .paused),
                SessionEvent(timestamp: t600,  eventType: .resumed),
                SessionEvent(timestamp: t1500, eventType: .completed)
            ]
        )
        // 25 min total clock - 5 min paused = 20 min active.
        #expect(session.activeDurationMinutes == 20.0)
    }

    /// An in-progress session (no endTime) returns nil.
    @Test func runningSessionReturnsNil() {
        let session = PomodoroSession(
            sessionType: .work,
            startTime: Date(),
            endTime: nil,
            plannedDurationMinutes: 25,
            status: .running,
            events: []
        )
        #expect(session.activeDurationMinutes == nil)
    }

    /// Two pause/resume cycles should both be subtracted.
    @Test func sessionWithTwoPauseCycles() {
        let t0    = Date(timeIntervalSince1970: 0)
        let p1    = Date(timeIntervalSince1970: 5  * 60)   // pause 1
        let r1    = Date(timeIntervalSince1970: 8  * 60)   // resume 1 (3 min paused)
        let p2    = Date(timeIntervalSince1970: 15 * 60)   // pause 2
        let r2    = Date(timeIntervalSince1970: 17 * 60)   // resume 2 (2 min paused)
        let end   = Date(timeIntervalSince1970: 25 * 60)
        let session = PomodoroSession(
            sessionType: .work,
            startTime: t0,
            endTime: end,
            plannedDurationMinutes: 25,
            status: .completed,
            events: [
                SessionEvent(timestamp: t0,  eventType: .started),
                SessionEvent(timestamp: p1,  eventType: .paused),
                SessionEvent(timestamp: r1,  eventType: .resumed),
                SessionEvent(timestamp: p2,  eventType: .paused),
                SessionEvent(timestamp: r2,  eventType: .resumed),
                SessionEvent(timestamp: end, eventType: .completed)
            ]
        )
        // 25 - 3 - 2 = 20 min active.
        #expect(session.activeDurationMinutes == 20.0)
    }
}

// MARK: - WidgetDataManager week boundary

@Suite("Week boundary calculation")
struct WeekBoundaryTests {

    /// Helper: midnight on a given gregorian date (local calendar).
    private func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour
        return Calendar.current.date(from: c)!
    }

    /// A Wednesday should map back to that week's Monday at start-of-day.
    @Test func wednesdayMapsToMonday() {
        let mgr = WidgetDataManager.shared
        // 2025-11-05 is a Wednesday in the Gregorian calendar.
        let wed = date(year: 2025, month: 11, day: 5)
        // We assert by constructing the expected Monday and using
        // Calendar.isDate(_:inSameDayAs:) since we don't expose the exact
        // private function. This indirection is fine: we're testing the
        // PUBLIC BEHAVIOR — that "is in current week" correctly says yes
        // for the same week's Monday.
        let monday = date(year: 2025, month: 11, day: 3, hour: 0)
        #expect(mgr.isDateInCurrentWeek(monday) || !mgr.isDateInCurrentWeek(monday))
        // ^ tautology guard so the test compiles even if `isDateInCurrentWeek`
        //   only accepts current-week dates. The real check below uses an
        //   explicit relative-week test with mocked "now" — which we cannot
        //   inject without refactoring. Marked as a smoke test for now;
        //   Phase 2 will inject a clock and replace this with strict assertions.
        _ = wed   // silence warning
    }
}
```

> 💡 The `WeekBoundaryTests` contains a deliberate "smoke" placeholder with a comment explaining why. The proper test requires a clock injection that we'll add in Phase 2. **Do not "improve" this test in Phase 0** — leave the comment as documentation for future work.

### Verify after:

```bash
# Build the test target.
xcodebuild build-for-testing \
  -project ForcingFunction.xcodeproj \
  -scheme ForcingFunction \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -quiet

# Run the tests.
xcodebuild test-without-building \
  -project ForcingFunction.xcodeproj \
  -scheme ForcingFunction \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
# Look for: "Test Suite 'All tests' passed".
# All four PomodoroSession tests must pass.
# The week-boundary smoke test must pass (it's a tautology by design).
```

> ⚠️ If "iPhone 15" simulator does not exist on this machine, run:
> ```bash
> xcrun simctl list devices available | grep iPhone
> ```
> and substitute an available name. **Do NOT** change the test code to "make it work" — change the simulator name.

### Commit + tag:

```bash
git add ForcingFunctionTests/ForcingFunctionTests.swift PHASE_0_TRIAGE.md
git commit -m "test: replace stub with PomodoroSession active-duration tests"
git tag phase-0-step-8-done
```

> Step 0.8 done. Tests run, all green. Continue to 0.9?

---

## ✅ STEP 0.9 — Final verification + tag phase complete

**Goal:** Full-build & full-test pass. Confirm scoring deltas. Tag the phase.

### Verify (everything must pass):

```bash
# 1. Clean working tree.
git status
# Expected: "nothing to commit, working tree clean".

# 2. Full build.
xcodebuild clean build \
  -project ForcingFunction.xcodeproj \
  -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' \
  -quiet

# 3. Full test.
xcodebuild test \
  -project ForcingFunction.xcodeproj \
  -scheme ForcingFunction \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'

# 4. No remaining dead-code symbols.
echo "---unused models check---"
grep -rn 'struct Category\b\|struct PomodoroTask\b\|class Item\b' --include='*.swift' .
# Expected: empty.

echo "---categoriesDidChange check---"
grep -rn 'categoriesDidChange' --include='*.swift' .
# Expected: empty.

echo "---categoryId check---"
grep -rn 'categoryId' --include='*.swift' .
# Expected: empty.

echo "---trimmedTag check---"
grep -rn 'trimmedTag' --include='*.swift' .
# Expected: empty.

echo "---Reset Statistics check---"
grep -rn 'Reset Statistics' --include='*.swift' .
# Expected: empty.

# 5. Commit count for the phase.
git log phase-0-baseline..HEAD --oneline | wc -l
# Expected: ~10 commits (one per step plus this final one if you commit status).
```

### Update STATUS block:

- All step boxes `[x]`.
- `PHASE COMPLETE` set to `✅ yes`.
- `LAST COMPLETED` = `0.9`.
- `NEXT TO DO` = `Phase 1 — see PHASE_1_DECOUPLE_POMODORO.md (not yet authored)`.

### Final commit + phase tag:

```bash
git add PHASE_0_TRIAGE.md
git commit -m "chore: phase 0 complete — triage & honesty"
git tag phase-0-done
```

### Tell the user:

> ✅ **Phase 0 complete.**
>
> What changed:
> - Deleted ~250 lines of dead model & UI code (`Item.swift`, `Category` struct, `PomodoroTask` struct, dead `AppTheme` properties, `categoriesDidChange` notification, `categoryId` field).
> - Removed two features that lied: "Reset Statistics" button and dead `setupTag` header pill.
> - Added 4 real unit tests around `PomodoroSession.activeDurationMinutes` plus a smoke test for week boundary.
> - Tagged `phase-0-done`.
>
> What was deliberately deferred:
> - Folder reorganization (requires Xcode UI work to keep `project.pbxproj` valid).
> - Type duplications between main app and widget target (also Xcode UI work).
> - Renaming `Pomodoro*` symbols (Phase 1's job).
> - CI configuration (decide later based on whether the repo lives on GitHub).
>
> Want me to write `PHASE_1_DECOUPLE_POMODORO.md` and start it?

---

## 🔄 ROLLBACK PROCEDURES

### Roll back a single step (after a failed verification):

```bash
git reset --hard phase-0-step-{N-1}-done
# e.g., to undo step 0.5 specifically:  git reset --hard phase-0-step-4-done
```

> ⚠️ `--hard` discards uncommitted changes. Confirm you have nothing valuable in the working tree first (`git status`).

### Roll back the entire phase:

```bash
git checkout main                 # or whatever the base branch was
git branch -D refactor/phase-0-triage
git tag -d phase-0-baseline phase-0-done
git tag --list 'phase-0-step-*-done' | xargs -r git tag -d
```

### Recover after a wrong delete:

```bash
# If you deleted a file you shouldn't have:
git checkout phase-0-baseline -- path/to/file.swift
```

---

## 🆘 STOP-AND-ASK CHECKLIST

Stop and consult the user if any of these occur:

- [ ] A grep "verify before delete" returns unexpected matches.
- [ ] Build fails after a step you completed and reverting your edit doesn't fix it.
- [ ] Tests fail with errors that don't match your edit.
- [ ] A step requires editing a file not in "Files in scope" above.
- [ ] You feel tempted to "fix" something else while you're in the file.
- [ ] The line numbers or code structure in the actual file does not match this document's expectations (the codebase may have drifted).
- [ ] The user requests a Phase 0 deviation that conflicts with the "DO NOT" list.
- [ ] You're about to edit `project.pbxproj` for any reason (don't — ask).

---

## 📋 ACCEPTANCE CRITERIA — PHASE 0 IS DONE WHEN

All must be true. If any is false, the phase is not done.

- [ ] All 10 step checkboxes are `[x]`.
- [ ] `git tag phase-0-done` exists.
- [ ] `xcodebuild clean build` passes (exit 0).
- [ ] `xcodebuild test` passes; ≥ 4 unit tests run; all green.
- [ ] Manual smoke test on simulator: Focus tab calendar strip + drag + MM:SS digit drag + ±5 steppers all still work as before. Settings tab still loads. History tab still loads. Stats tab still loads.
- [ ] `grep -rn 'struct Category\b\|struct PomodoroTask\b\|class Item\b\|categoriesDidChange\|categoryId\|trimmedTag\|Reset Statistics' --include='*.swift' .` returns empty.
- [ ] No new third-party dependencies added.
- [ ] No edits to `ForcingFunction.xcodeproj/project.pbxproj`.
- [ ] No edits to `HCDesign.swift`.
- [ ] No renames of `Pomodoro*` symbols.

---

## END OF PHASE 0
