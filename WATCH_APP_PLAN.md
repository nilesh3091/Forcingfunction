# Apple Watch Companion App — Implementation Plan

This plan covers Phase 1 (remote control + glance) and Phase 3 (complications + HealthKit). Phase 2 (independent watch timer) is intentionally skipped — see "Out of scope" at the bottom.

---

## Context for a fresh session

ForcingFunction is an iOS Pomodoro/focus timer app. The watch app is a companion: phone is the source of truth, watch is a thin client.

### Existing layout
- Main iOS app: `ForcingFunction/`, bundle ID `NileshKumar.ForcingFunctionApp`
- Widget extension: `ForcingFunctionWidget/`, bundle ID `NileshKumar.ForcingFunctionApp.ForcingFunctionWidget`
- App Group: `group.com.forcingfunction.shared`
- iOS deployment target: 18.6
- Tabs: Timer, Calendar, Stats, Settings (`ForcingFunction/MainTabView.swift`)

### Key classes
- `ForcingFunction/TimerViewModel.swift` — ~1100-line central state owner. `@AppStorage` for settings & saved timer state. Don't refactor it. Just add new methods.
- `ForcingFunction/Models.swift` — `PomodoroSession`, `SessionType`, `TimerState`, `AppTheme`, etc. **Imports UIKit at the top** — won't compile on watchOS as-is.
- `ForcingFunction/PomodoroDataStore.swift` — JSON file in Documents dir. Phone-only.
- `ForcingFunction/LiveActivityManager.swift` — iOS-only (ActivityKit). Don't touch.
- `ForcingFunction/HealthKitManager.swift` — already cross-platform.
- `ForcingFunction/WidgetDataManager.swift` — writes to App Group `UserDefaults`.

### Important: how the two devices talk
- **App Groups don't bridge iPhone↔Watch.** They're per-device.
- Bridge is `WatchConnectivity` (`WCSession`):
  - `updateApplicationContext` — latest-state, queued, reliable. Use for snapshots.
  - `sendMessage` — live, both apps reachable. Use as a "hurry up" nudge.
  - `transferUserInfo` — queued, delivered eventually. Fallback for commands when not reachable.

---

## Manual prerequisites (user must do in Xcode before this session starts)

Verify all of these exist before writing any code. If any are missing, stop and tell the user.

1. **Watch App target** named `ForcingFunctionWatch`, bundle ID `NileshKumar.ForcingFunctionApp.watchkitapp` (Xcode auto-pairs by bundle ID prefix).
2. **Watch Widget Extension target** (for complications), bundle ID like `NileshKumar.ForcingFunctionApp.watchkitapp.ComplicationExtension`.
3. **App Groups** capability enabled on both new targets, group `group.com.forcingfunction.shared`.
4. **HealthKit** capability enabled on the watch app target.
5. **Background Modes** → "Workout processing" enabled on the watch app target.
6. Apple Developer account signed in to Xcode.
7. **Resolve `IPHONEOS_DEPLOYMENT_TARGET = 26.0`** on the existing widget target before adding the watch target — looks like an accidental edit. Confirm with user whether this is intentional.

---

## Phase 1 — Remote control + glance

**Goal:** start/pause/end the timer from the wrist, see remaining time and today's focus minutes vs. goal. Watch does nothing useful when phone is unreachable.

### Step 1.1 — Make `Models.swift` cross-platform

The file imports UIKit at the top. Watch target can't compile UIKit code.

- Split `Models.swift` into two files:
  - **Keep `Models.swift`** with pure data types: `SessionType`, `TimerState`, `SessionEvent`, `EventType`, `SessionStatus`, `CategoryColor` (will need adjustment — its `color` property uses SwiftUI `Color`, which is fine), `Category`, `PomodoroSession`, `PomodoroTask`, `AppSettings`. Remove `import UIKit` from the top.
  - **Move `AppTheme` and the `dyn`/`dynA` helpers to a new `ForcingFunction/AppTheme.swift`.** Add this file to the iOS app and iOS widget targets only — NOT the watch target.
- For the watch, create `ForcingFunctionWatch/WatchTheme.swift` with a minimal palette (just the colors the watch UI actually uses). SwiftUI `Color` only, no UIKit.
- Add `Models.swift` to the watch app target's membership.
- Make `TimerState` conform to `Codable` (it currently doesn't — required for the snapshot below).

### Step 1.2 — Define the wire format

Create `Shared/WatchProtocol.swift` and add to **both** phone and watch targets.

```swift
import Foundation

enum WatchCommand: Codable {
    case start(minutes: Double, sessionType: SessionType)
    case pause
    case resume
    case end
    case requestSnapshot
}

struct TimerSnapshot: Codable {
    let remainingSeconds: Int
    let timerState: TimerState
    let sessionType: SessionType
    let startTime: Date?
    let pausedDuration: TimeInterval
    let todayFocusMinutes: Int
    let dailyGoalMinutes: Int
    let updatedAt: Date
}
```

### Step 1.3 — `WCSessionManager`

Create `Shared/WCSessionManager.swift` and add to both targets. One file, conditionally compiled where iOS/watchOS APIs differ.

- Singleton, activates `WCSession.default` in `init`
- Conforms to `WCSessionDelegate`. Implement:
  - `session(_:activationDidCompleteWith:error:)` — both platforms
  - `sessionDidBecomeInactive(_:)` and `sessionDidDeactivate(_:)` — iOS only (`#if os(iOS)`)
  - `session(_:didReceiveMessage:replyHandler:)` — handle `WatchCommand` on phone, reply with current snapshot
  - `session(_:didReceiveApplicationContext:)` — handle `TimerSnapshot` on watch
- Phone-facing API:
  - `sendSnapshot(_ snapshot: TimerSnapshot)` — calls `updateApplicationContext`
- Watch-facing API:
  - `send(command: WatchCommand)` — `sendMessage` when reachable, fall back to `transferUserInfo`
  - `@Published var latestSnapshot: TimerSnapshot?` — for SwiftUI to bind to

### Step 1.4 — Wire into `TimerViewModel`

In `ForcingFunction/TimerViewModel.swift`:

- Add `func apply(command: WatchCommand)`:
  - `.start(minutes, type)` → set `selectedMinutes`, `currentSessionType`, call existing `startTimer()`
  - `.pause` → existing `pauseTimer()`
  - `.resume` → existing `resumeTimer()`
  - `.end` → existing `endTimer()` or equivalent
  - `.requestSnapshot` → no-op, caller will read `currentSnapshot()`
- Add `func currentSnapshot() -> TimerSnapshot`:
  - Build from `remainingSeconds`, `timerState`, `currentSessionType`, `startTime`, `pausedDuration`, `dataStore.getTodayCompletedWorkFocusMinutes()`, `focusGoalMinutesForToday()`, `Date()`.
- After every state mutation that already triggers a UI update (start, pause, resume, tick, end, completion), call `WCSessionManager.shared.sendSnapshot(currentSnapshot())`. Throttle to once per second using `Combine`'s `.throttle(for: 1.0, scheduler: RunLoop.main, latest: true)` on a publisher to avoid hammering the channel during ticks.

In `ForcingFunction/ForcingFunctionApp.swift`:
- Activate `WCSessionManager.shared` in `init` (alongside the existing widget data init).

### Step 1.5 — Watch UI

Create in `ForcingFunctionWatch/`:

- **`ForcingFunctionWatchApp.swift`** — `@main` SwiftUI App. Instantiates a `WatchTimerStore: ObservableObject` (thin wrapper over `WCSessionManager.shared.latestSnapshot`).
- **`WatchRootView.swift`** — switches on `snapshot.timerState`:
  - `.idle`: minute picker (Digital Crown via `.focusable().digitalCrownRotation($minutes, from: 5, through: 120, by: 5, sensitivity: .medium)`), big "Start" button at bottom, today progress text below the picker.
  - `.running`: large remaining-time readout (mm:ss), session-type chip, two buttons (Pause + End).
  - `.paused`: same as running but Pause becomes Resume.
  - `.completed`: brief "Done" with auto-return to idle after ~2s.
- Each button calls `WCSessionManager.shared.send(command: ...)`. Optimistically update local state; the next snapshot from the phone reconciles.

### Step 1.6 — Haptics

When snapshot transitions to `.completed` (detect via `onChange` on the published snapshot), call `WKInterfaceDevice.current().play(.notification)`.

### Step 1.7 — Notifications

Nothing to do. iOS notifications mirror to the watch automatically when the iPhone is locked or wrist is up.

### Phase 1 acceptance
- [ ] Start a timer on the watch, phone starts the same timer within 1s
- [ ] Pause/resume/end from either device, both stay in sync within 1s
- [ ] Watch idle screen shows today's minutes and daily goal correctly
- [ ] Haptic fires on completion on both devices
- [ ] Watch shows a sane "phone unreachable" state when the phone is off

---

## Phase 3 — Complications + HealthKit

**Goal:** watch face complications, heart rate during focus sessions, keep the timer alive with screen off via a fake workout session.

### Step 3.1 — Watch widget extension (complications)

Build out the Watch Widget Extension target the user added.

- Reuse the data model `WeeklyWidgetData` from `ForcingFunction/WidgetDataManager.swift` — add the file (or just the struct) to the watch widget target.
- **Data source on watch:** watch-side `UserDefaults.standard`. `WCSessionManager` writes the latest `TimerSnapshot` and a derived `WeeklyWidgetData` payload to it whenever a snapshot arrives. Don't try to use App Groups across devices — they don't bridge.
- Provide widget kinds for these families (watchOS 10+):
  - `.accessoryCircular` — ring showing today's focus / goal
  - `.accessoryRectangular` — minutes + small bar
  - `.accessoryCorner` — minimal text + tick marks
  - `.accessoryInline` — single-line "Focus 1h 23m / 2h"
- Refresh policy: timeline reloads on every new snapshot. Call `WidgetCenter.shared.reloadAllTimelines()` from the watch when `WCSessionManager` writes new data.

### Step 3.2 — HealthKit on watch

- Copy `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` from `ForcingFunction/Info.plist` into `ForcingFunctionWatch/Info.plist`.
- Add `ForcingFunction/HealthKitManager.swift` to the watch target's membership. Should compile as-is.

### Step 3.3 — `HKWorkoutSession` for background execution

This is the trick that keeps the watch timer alive with the screen off. Without it, watchOS suspends the app within ~1 minute of wrist-down.

Create `ForcingFunctionWatch/WorkoutKeepalive.swift`:

- When the watch starts a focus session (or the snapshot transitions to `.running` for `.work`):
  - Build `HKWorkoutConfiguration(activityType: .mindAndBody, locationType: .indoor)`
  - Start an `HKWorkoutSession` and attach an `HKLiveWorkoutBuilder`
  - Begin collection
- When session ends (`.completed`, `.idle`, or user hits End):
  - End the workout builder, finalize the workout
- Only do this for `.work` sessions, not breaks
- Skip if the user hasn't granted HealthKit permission — no-op gracefully

### Step 3.4 — Heart rate back to phone (optional)

Pass the average HR back so the phone Stats view can show it.

- Extend the wire format with a separate watch→phone struct (don't bloat `TimerSnapshot`):
  ```swift
  struct WatchSessionResult: Codable {
      let sessionStartTime: Date
      let averageHeartRate: Double?
      let endedAt: Date
  }
  ```
- When a watch-side workout ends, `WCSessionManager` sends this via `transferUserInfo` (queued, reliable).
- Phone receives it and updates the matching `PomodoroSession` (matched by `startTime` proximity within ~5s) by adding an optional `averageHeartRate: Double?` field. **Make the field optional and nil-default for backward-compatible decoding** of existing JSON.
- Display in `StatsView` for sessions that have HR.

### Phase 3 acceptance
- [ ] Start focus on watch, drop wrist, screen off, timer still completes correctly and haptic fires
- [ ] Each complication family renders today's progress and updates within ~1 min of phone-side change
- [ ] Tapping a complication launches the watch app
- [ ] (If 3.4 done) StatsView shows average HR for sessions that recorded it; sessions without HR render unchanged

---

## Out of scope: Phase 2 (independent watch timer)

This plan does NOT let the user start a timer on the watch when the phone is unreachable. If they hit Start with no phone nearby in the Phase 1 build, the watch should show a clear "phone unreachable" state rather than appearing to start.

Phase 2 would require:
- Extracting a pure `TimerEngine` from `TimerViewModel`
- Watch-side `PomodoroDataStore` (JSON in watch's documents dir)
- Sync via `transferUserInfo`, merging by session UUID with last-writer-wins

Don't build any of it.

---

## Suggested order

1. **Pre-flight** — verify all manual prerequisites above.
2. **Phase 1 Step 1.1** — Models split. Build iOS and widget targets clean before continuing.
3. **Phase 1 Steps 1.2–1.4** — protocol, WCSessionManager, ViewModel hooks. Test on iOS first (unit test the snapshot builder; integration test the message round-trip in simulator).
4. **Phase 1 Step 1.5** — Watch UI. First end-to-end test on hardware (simulator can't fully test WCSession).
5. **Phase 1 acceptance** — sign off before continuing.
6. **Phase 3 Steps 3.1–3.3** — complications, HealthKit, workout keepalive.
7. **Phase 3 Step 3.4** — HR pipeline (optional, ask user if they want it).
8. **Phase 3 acceptance.**

---

## Gotchas

- **`sendMessage` requires both apps reachable.** Always treat `applicationContext` as the source of truth; `sendMessage` is just a nudge.
- **Snapshot throttling matters.** The timer ticks every second; sending every tick over `WCSession` is wasteful. Throttle to 1Hz max, send extras only on state transitions.
- **HKWorkoutSession permissions** — the user has to grant HealthKit on first use. Handle the not-authorized case (no keepalive, watch will suspend after wrist-down).
- **Live Activities on watch** — they don't run there, but iPhone Live Activities show up in the watch Smart Stack automatically. Don't try to add a watch Live Activity target.
- **Deployment target** — pick watchOS 10.0+ to use accessory complication families. Confirm with user.
- **Backward-compat** — when adding `averageHeartRate` to `PomodoroSession`, keep it optional so existing `pomodoro_sessions.json` files decode cleanly.
