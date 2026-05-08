# CLAUDE.md — Read this first, every session

You are working on **ForcingFunction**, an iOS Pomodoro app being refactored toward a "Pomodoro app where every session counts toward a project" identity. There is a multi-phase engineering plan and we are partway through it.

---

## 🛑 STEP ZERO — RUN BEFORE ANYTHING ELSE

**The Claude Desktop app spawns each new session inside an isolated git worktree under `.claude/worktrees/<random-name>/`. Files written there are invisible to other sessions and to the user's main repo. This silently breaks every multi-session plan if not handled.**

Before reading anything else, do this:

```bash
pwd
```

If the output contains `.claude/worktrees/`, you are in an isolated worktree. **Immediately switch to the main repo:**

```bash
cd "/Users/niles/Library/Mobile Documents/com~apple~CloudDocs/Projects/ForcingFunction"
pwd   # confirm path no longer contains ".claude/worktrees/"
```

**All file reads, edits, commits, and planning-doc updates from this point on MUST happen at the main repo path above.** Never write inside `.claude/worktrees/*`. If a later tool call lands you back in a worktree path (cwd resets), `cd` back to the main repo path first.

If `cd` to the main repo fails, STOP and tell the user. Do not invent a path.

---

## ⚡ FAST ANSWER: "Where were we / what's next?"

When the user asks any variant of "where were we", "what's next", "what phase are we on", or "continue":

1. **List the active phase file.** Run:
   ```bash
   ls PHASE_*_*.md
   ```
2. **Open the file with the highest number that is not yet marked complete.** Read its `📍 CURRENT STATUS` block at the top. That block is the single source of truth.
3. **Read git tags** to cross-check:
   ```bash
   git tag --list 'phase-*' --sort=-creatordate | head -10
   ```
4. **Report to the user** in this exact format:
   > Active phase: **Phase N — [name]**
   > Last completed step: **N.X — [description]** (tagged: `phase-N-step-X-done`)
   > Next step: **N.Y — [description]**
   > Want me to proceed with step N.Y?

5. **Wait for user's "yes" before doing anything else.** Do not skip steps. Do not reorder. Do not "improve while you're there."

---

## 🚫 GLOBAL NON-NEGOTIABLES (apply to every phase)

These behaviors and surfaces are **locked**. Do not change them in any phase unless the active phase file explicitly authorizes it.

1. **The Pomodoro duration-setting UI in `TimerView.swift`** — DO NOT touch:
   - The 24-hour vertical calendar strip on the left
   - The draggable bottom handle on the session block (resize duration)
   - The MM:SS digit drag-to-resize on the timer card
   - The ±5 stepper buttons
   - The "now" red line, elapsed-fill, live time tick

2. **The `HC` design system** in `ForcingFunction/HCDesign.swift` — colors, type scale, radii, shadows. New code uses `HC.bg`, `HC.card`, `HC.ink`, `HC.red`, etc. Do not introduce new color literals.

3. **The Pomodoro core loop** — `SessionType` enum, work / short break / long break cycle, Live Activity, Dynamic Island, home widget. Phase 1 will refactor this; until then, don't touch.

4. **Existing user data** — Sessions stored in `Documents/pomodoro_sessions.json`. Projects in `Documents/projects.json`. Any change to model schema MUST preserve forward-compatibility (decoders ignore unknown fields). Never break existing user data.

---

## 🛑 STOP-AND-ASK TRIGGERS (every session)

If any of these happen, STOP and ask the user before proceeding:

- The active phase file's `📍 CURRENT STATUS` block disagrees with git tags.
- A step says "do X to file Y" but file Y doesn't exist or has been moved.
- Build fails after a step you completed and you don't immediately understand why.
- The user requests something that is not in the active phase.
- A step requires Xcode UI work (project.pbxproj target membership changes, drag-drop reorganization). DO NOT edit `project.pbxproj` directly. Ask the user to do it in Xcode.
- You realize a step would change a "Global Non-Negotiable" above.
- Tests fail after your change and you cannot fix them by reverting only your edits.

---

## 🔧 VERIFICATION POLICY (LEAN — DO NOT OVER-VERIFY)

**The bare-minimum gate per step:**

```bash
# Build only — fast, no simulator boot.
xcodebuild build \
  -project ForcingFunction.xcodeproj \
  -scheme ForcingFunction \
  -destination 'generic/platform=iOS Simulator' \
  -quiet
```

**`xcodebuild test` runs ONCE per phase, at the end** — not per step. Booting a simulator costs minutes and can hang; don't pay that cost ten times per phase.

**Manual / simulator UI smoke tests are NEVER run by the AI agent.** If the user wants to manually poke the app, they will. Do not boot the simulator app, do not navigate the UI, do not "verify by clicking." Trust the build + tests + greps.

**Greps before deletions are mandatory** (cheap, prevents disasters):
```bash
grep -rn "SymbolName" --include='*.swift' .
```

That's the entire verification toolkit. Anything beyond this is over-engineering.

---

## ✂️ DOCUMENT BREVITY RULE (applies to all future phase files)

Future `PHASE_N_*.md` files must be **terse**:
- Target ≤ 300 lines per phase doc (Phase 0 was 750 — too long).
- Per-step section: ~10–25 lines, not 60+. Just: goal, files, action, single grep/build verify, commit message.
- No "tip" callouts, no prose explanations of why a step exists, no per-step rollback prose (one global rollback section at the bottom).
- No per-step "Stop & ask" sub-section — one global list at the top of the phase.
- No "manual smoke test" sections, ever.

If a phase doc starts ballooning past ~300 lines, stop and ask the user whether to split it.

---

## 📋 PROGRESS TRACKING PROTOCOL (every step, every phase)

Before starting any step:
1. Update the `📍 CURRENT STATUS` block: change the step's `[ ]` to `[~]` (in progress). No separate commit for this — fold it into the step's commit.

After completing any step:
1. Run `xcodebuild build` + the step's grep checks. They must pass.
2. Update the `📍 CURRENT STATUS` block: change `[~]` to `[x]` (done).
3. Update "Last completed step" and "Next step" lines.
4. Commit your changes with the message format from the step.
5. Tag the commit: `git tag phase-N-step-X-done`.
6. Stop and tell the user: "Step N.X complete. Want me to continue to N.Y?"

**Never batch multiple steps into one commit.** One step → one commit → one tag.

---

## 🛡️ GENERAL SAFETY RULES (every action)

- **Never delete a file or symbol without first running `grep -rn 'Symbol' --include='*.swift' .` and confirming no references remain.** The active phase file has explicit "verify before delete" commands for every deletion; run them.
- **Never edit a file outside the explicit "Files in scope" list of the current step.**
- **Never add new dependencies, frameworks, or third-party libraries** unless the active phase explicitly says to.
- **Never write `// TODO`** without an associated step in the phase file. If you find a real issue out of scope, surface it to the user and ask whether to add it to a future phase.
- **Never `git push --force`, `git reset --hard`, or `git checkout --` to recover from a mistake.** Use `git revert` (creates a new commit). If unsure, stop and ask.
- **Never edit `ForcingFunction.xcodeproj/project.pbxproj` directly.** Xcode-level changes are user-only.
- **If a step's exact instruction conflicts with what you find in the code** (e.g., line numbers shifted), STOP, report the discrepancy, ask the user.

---

## 📁 ACTIVE PHASE FILES

The plan lives in markdown files at the repo root, one per phase:

| File | Phase | Status |
|---|---|---|
| `PHASE_0_TRIAGE.md` | 0 — Triage & honesty | (check the file) |
| (later phases will be added one at a time as work progresses) | | |

When a phase finishes, its file is left in place (with all checkboxes `[x]`) as historical record. The next phase file is added.

---

## 🧭 PROJECT ORIENTATION (one-paragraph summary)

ForcingFunction is a SwiftUI iOS app: a Pomodoro timer with a 24-hour day-strip UI, project tagging, HealthKit workout integration, Live Activities, Dynamic Island, and a home-screen widget. Built around `TimerViewModel` (currently a 1,060-line god class), two JSON data stores (`PomodoroDataStore`, `ProjectStore`), and a custom design system (`HC`). The refactor goal is: clean foundation (P0–P3), then make projects first-class (P4), real stats (P5), onboarding & polish (P6), CloudKit sync + Apple Watch (P7), launch (P8).

Audit summary stays in this file's git history if you need it.
