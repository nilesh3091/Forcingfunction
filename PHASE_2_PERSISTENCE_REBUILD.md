# PHASE 2 — PERSISTENCE REBUILD (SWIFTDATA)

> **Goal:** Replace JSON stores with a single SwiftData-backed repository layer that’s async-safe, indexed, schema-versioned, and migration-ready. Preserve existing user data.
>
> **Time:** ~3 weeks.
> **Risk:** High (migration + SwiftData edges).
>
> **Non-negotiables:** Do not touch protected duration-setting UI surfaces in `TimerView.swift`. Do not edit `ForcingFunction.xcodeproj/project.pbxproj` directly.

---

## 📍 CURRENT STATUS — single source of truth

```
═══════════════════════════════════════════════════════════
  ACTIVE PHASE      : 2 — Persistence rebuild (SwiftData)
  PHASE STARTED     : 2026-05-08
  LAST COMPLETED    : 2.0 — Setup & baseline (branch + baseline tag)
  CURRENTLY ON      : 2.5 — Replace scattered @AppStorage with single Codable blob
  NEXT TO DO        : 2.6 — Centralize minutes math (single billed-minutes truth) + update call sites
  PHASE COMPLETE    : ⛔️ no
═══════════════════════════════════════════════════════════

STEP CHECKLIST:

  [x] 2.0  Setup & baseline (branch + baseline tag)
  [x] 2.1  SwiftData container + models (no view changes yet)
  [x] 2.2  Repository layer + Environment injection
  [x] 2.3  One-time migration from legacy JSON → SwiftData
  [x] 2.4  Replace app reads/writes to use repository (no JSON stores in app flow)
  [~] 2.5  Replace scattered @AppStorage with single Codable blob
  [ ] 2.6  Centralize minutes math (single billed-minutes truth) + update call sites
  [ ] 2.7  Remove remaining `Data(contentsOf:)` / `.write(to:)` from app code
  [ ] 2.8  Add repository-layer unit tests (in-memory container)
  [ ] 2.9  Final verification + tag phase done

LEGEND:  [ ] not started   [~] in progress   [x] done   [-] skipped (with reason)
```

---

## ✅ Phase-wide exit criteria

- **No JSON file I/O in app code** (`Data(contentsOf:)`, `write(to:)`) for sessions/projects.
- **No app singletons for data stores** (`static let shared`) used by views/view-models.
- **Existing user data migrates losslessly** on first launch with SwiftData store missing.
- **Repository layer is testable** with an in-memory SwiftData container.
- **Build green.** `xcodebuild build` gate per step; `xcodebuild test` at Phase end.

---

## 🔧 Verification command (minimum gate)

```bash
xcodebuild build \
 -project ForcingFunction.xcodeproj \
 -scheme ForcingFunction \
 -destination 'generic/platform=iOS Simulator' \
 -quiet
```

