# Handoff: Hour Cards — 10K Focus Timer Redesign

## Overview
A redesign of the 10K focus/pomodoro app, replacing the existing dial-based timer UI with a warm, card-stacked, type-forward design. Four screens: **Timer (Focus)**, **History (Log)**, **Stats (Shape)**, and **Settings (Tune)**.

## About the Design Files
The files in this bundle are **design references created in HTML/JSX** — prototypes showing intended look and behavior, not production code to copy directly. The task is to **recreate these designs in the target codebase's existing environment** (likely React Native / SwiftUI / Kotlin for the mobile app) using its established patterns, components, and styling conventions. Do not ship the HTML.

## Fidelity
**High-fidelity (hifi).** Colors, typography, spacing, and layout are intentional and final. Recreate pixel-perfectly using the codebase's existing libraries.

## Design Direction
- **Warm off-white surface** with cream "paper" cards on top.
- **Expressive display type** — heavy Helvetica/Arial Black, tight tracking, big numerals.
- **Tomato-red as primary accent**, deep blue and ink as secondary.
- **No circular dial.** Time is shown via large numerals + a horizontal progress bar.
- **Card stack architecture** — hero card + small stat cards + tab bar at bottom.
- **Maximalist confidence** in scale and color blocking, but restrained density.

## Design Tokens

### Colors
| Token | Hex | Usage |
|---|---|---|
| `HC_BG` | `#EFEAE0` | Page background (warm off-white) |
| `HC_CARD` | `#FFFCF5` | Card surface (cream) |
| `HC_INK` | `#191714` | Primary text / dark UI |
| `HC_MUTED` | `#8A8475` | Secondary text / labels |
| `HC_LINE` | `#D8D2C2` | Borders, hairlines, divider lines |
| `HC_RED` | `#E54B2A` | Primary accent — start button, active states, alerts (tomato) |
| `HC_BLUE` | `#2E4DDB` | Secondary accent — long sessions, "longest" stat |
| `HC_YEL` | `#F5D02C` | Tertiary accent (reserved, currently unused) |

### Typography
| Role | Stack | Notes |
|---|---|---|
| Display | `"Helvetica Neue", Helvetica, Arial Black, sans-serif` | Used for big numerals & headlines. Weight 800–900. Tight letter-spacing (negative). |
| Text | `-apple-system, "SF Pro Text", system-ui, sans-serif` | Body and UI text. Weights 400/500/600. |
| Mono | `"SFMono-Regular", ui-monospace, Menlo, monospace` | Small caps labels, time stamps, durations. Letter-spacing ~1.0–1.2. |

Replace with the codebase's equivalent display/sans/mono pairing if these aren't available — the visual character (heavy, tightly tracked display + neutral sans + mono labels) is what matters.

### Spacing
- Outer page padding: `20px` horizontal
- Top safe area: `60px` (status bar)
- Card internal padding: `16–22px`
- Vertical rhythm between major blocks: `18–22px`
- Tab bar: `10px 12px 22px` (last value is bottom safe area)

### Border Radius
- Hero cards: `22px`
- Small stat / list cards: `14–18px`
- Pills / chips: `18px`
- Buttons (primary): `30px` (full pill, height 60)
- Tags (inline): `8px`
- Color block on log row: `1px`

### Shadow / Elevation
- Hero card: `0 12px 30px rgba(0,0,0,0.04)` — very subtle, just a hint of lift
- Other cards: no shadow, rely on `1px solid HC_LINE` border

---

## Screens

### 1. Timer (Focus) — `HCTimer`
Primary screen. User starts a focus session.

**Layout (top → bottom):**
1. **Header row** — `60px 20px 0` padding
   - Left: "SESSION №24" (mono, 10px, muted) + "Pomodoro 1." (display, 32px, 800, ink, letter-spacing -1.4)
   - Right: black tag chip — `HC_INK` background, `HC_BG` text, mono 10px, padding `6px 10px`, content "NBME"
2. **Hero card** — `HC_CARD`, `22px` radius, padding `24px 22px 22px`, subtle shadow
   - Top-right corner: 38×38 round badge, `HC_RED` background, white "1/4" display 13px 800 — indicates pomodoro position
   - Label: "REMAINING" (mono 10px muted)
   - **Big countdown**: `30:00` — display, **116px**, weight 900, line-height 0.86, letter-spacing -6.5, tabular-nums. The colon character is colored `HC_RED`.
   - Subtitle: "ends 14:30 · break 5m" (text 13px muted)
   - **Horizontal progress bar**: 14px tall, `HC_BG` fill, `HC_LINE` border, `7px` radius. Inner fill is `HC_RED`, inset 2px, `5px` radius. Three vertical tick markers at 25/50/75% (1px wide, `HC_LINE`, extending 4px above and below the bar).
3. **3-column stat strip** — gap 8px, each card `HC_CARD` / 14px radius / `12px 14px` padding
   - "TODAY" / "0m" (ink)
   - "GOAL" / "0%" (ink)
   - "STREAK" / "19d" (red)
   - Label: mono 9px muted, value: display 22px 800 letter-spacing -0.6
4. **Spacer** (flex 1)
5. **Action row** — gap 10px, `0 20px 16px` padding
   - Primary: full-pill "▶ Start focus" — `HC_RED` bg, white text, display 18px 800, height 60, radius 30
   - Secondary: 60×60 circle "SETUP" — `HC_CARD` bg, `HC_LINE` border, mono 11px ink
6. **Tab bar** (see below)

### 2. History (Log) — `HCHistory`
Day-grouped session journal.

**Layout:**
1. Header: "JOURNAL" (mono 10px muted) + "The log." (display 44px, 900, letter-spacing -2)
2. **Range chip row** — pills, one selected. Selected = `HC_INK` bg + `HC_BG` text. Unselected = `HC_CARD` bg + `HC_LINE` border + ink text. Text 12px 600. Padding `8px 14px`, radius 18px. Options: Day / Week / Month / All.
3. **Day cards** stack — each `HC_CARD`, 18px radius, `16px 18px` padding
   - Header: day label "TUE 29" (display 22px 900) + total "1h 12m" (mono 12px muted 700)
   - Sessions: each row has a 6×22 colored bar (tag color), tag name (display 14px 800), timestamp (mono 10px muted), and duration (display 16px 800 tabular-nums). Rows separated by dashed `HC_LINE`.
   - Tag colors: NBME = `HC_RED`, PHARM = `HC_BLUE`. (Extend palette as needed for new tags.)
4. Tab bar

### 3. Stats (Shape) — `HCStats`
Aggregate analytics.

**Layout:**
1. Header: "YOUR ARC" (mono 10px muted) + "Shape." (display 44px 900)
2. **Big red block** — `HC_RED` background, white text, 22px radius, `20px 22px` padding
   - Top label: "THIS WEEK" (mono 10px, 0.85 opacity)
   - Headline: "11h 47m" (display 76px 900, line-height 0.9, letter-spacing -3.5, tabular-nums)
   - Delta: "↑ 2h 12m vs last week" (text 13px, 0.9 opacity)
3. **Bar chart card** — `HC_CARD`, 18px radius, `16px 18px` padding
   - Row of 7 day-bars, gap 10px, height 110px
   - Bars are colored: today = `HC_RED`, rest day = `HC_LINE`, others = `HC_INK`. Min height 2%. 4px radius.
   - Day labels under each: mono 9px 700, today red, others muted
4. **2×2 stat grid** — gap 10px, each card `HC_CARD` 14px radius `12px 14px` padding
   - BEST DAY / Thu (ink)
   - BEST HOUR / 9 am (ink)
   - AVG SESSION / 42m (ink)
   - LONGEST / 2h 28m (`HC_BLUE`)
5. Tab bar

### 4. Settings (Tune) — `HCSettings`
Preferences.

**Layout:**
1. Header: "PREFERENCES" (mono 10px muted) + "Tune." (display 44px 900)
2. **Sections**, each:
   - Section label: mono 10px muted letter-spacing 1.2, padding `0 20px 8px`
   - Card: `HC_CARD` bg, 18px radius, `1px HC_LINE` border, margin-inline 20
   - Rows: padding `14px 18px`, separated by 1px `HC_LINE` top border
   - Row left: label (text 15px 500 ink)
   - Row right: value chip — display 14px 800 in section's accent color, `4px 10px` padding, 8px radius, `rgba(229,75,42,0.08)` background
3. Sections:
   - **SESSION** (accent `HC_RED`): Pomodoro / 45m, Short break / 5m, Long break / 15m, Cycle / ×4
   - **GOAL** (accent `HC_BLUE`): Daily target / 1h, Reminder / 8:00 am
   - **LOOK** (accent `HC_INK`): Mode / Light, Accent / Tomato
4. Tab bar

### Tab bar (shared) — `HCTabBar`
- 4 tabs: Focus / Log / Shape / Tune
- Glyph above label: ● / ◍ / ◐ / ◇ — colored `HC_RED` when active, `HC_MUTED` otherwise
- Label: text 11px, weight 700 (active) / 500 (inactive), color ink (active) / muted (inactive)
- Container: `HC_BG` bg, `1px HC_LINE` top border, padding `10px 12px 22px` (last is bottom safe area)
- 4-column grid, items centered vertically

---

## Interactions & Behavior

### Timer
- Tap **▶ Start focus** → countdown begins, button morphs to "Pause" (suggested: same pill, swap label and add a circular progress fill behind text). The horizontal progress bar fills left-to-right from 0% to 100% over the session duration.
- Tap **SETUP** → opens session config sheet (durations, tag picker)
- The colon in the countdown can blink at 1Hz while running (optional polish — keep red color)
- "1/4" badge increments after each completed pomodoro
- On session end: short haptic + sound, transition to a "Break" state (same layout, different copy/color: swap red for `HC_BLUE`, label "BREAK")

### History
- Tap a range pill → reload list scoped to that range
- Tap a session row → expand inline or push to a session detail screen with notes/edit
- Long-press a session → delete / edit menu
- Pull-to-refresh re-loads (if data is remote)

### Stats
- Tap a day-bar → drill into that day in the History screen
- Big red block could swipe between "This week" / "This month" / "All time"

### Settings
- Tap any row → push to a value picker (number wheel for durations, time picker for reminder, segmented control for Mode/Accent)

### Animations
- Card mount: 200ms `ease-out`, opacity 0→1 + translateY(8→0)
- Tab change: 150ms cross-fade
- Progress bar: linear, tied to elapsed time (no spring)

---

## State Management

```ts
type AppState = {
  session: {
    status: 'idle' | 'running' | 'paused' | 'break';
    pomodoroIndex: number;     // 1..4
    cycleLength: number;       // 4
    durationSec: number;       // 45*60
    elapsedSec: number;
    tag: string;               // "NBME"
  };
  today: { focusedMin: number; goalMin: number; streakDays: number; };
  log: Session[];              // grouped by day in UI
  stats: { weekTotalSec: number; weekDelta: number; bestDay: string; ... };
  settings: { pomodoro: number; shortBreak: number; longBreak: number; cycle: number; daily: number; reminder: string; mode: 'light'|'dark'; accent: string; };
};
```

State transitions:
- `idle → running` on Start
- `running → paused` on Pause
- `running → break` when `elapsedSec >= durationSec`
- `break → running` (next pomodoro) when break ends
- After 4 pomodoros: long break

---

## Assets
No image assets — design is pure type, color, and shape. The arrow/glyph characters (▶, ↑, ●, ◍, ◐, ◇) are Unicode and can be replaced with SF Symbols / Material icons in the target codebase if cleaner.

---

## Files in this bundle
- `README.md` — this document
- `preview.html` — open in a browser to see all four screens side-by-side
- `screens-app-cards.jsx` — React/JSX source for the four screens (`HCTimer`, `HCHistory`, `HCStats`, `HCSettings`, `HCTabBar`, `HCShell`). All design tokens are defined as constants at the top.
- `ios-frame.jsx` — the iOS device frame wrapper (`IOSDevice`) used by the prototypes for status bar / bezel. **Do not port this** — it's just for the design preview. The real app already lives inside an iOS frame.

The prototypes are sized at **340×736** logical pixels (a small iPhone canvas). Final implementation should be responsive across iPhone widths; treat the layout as proportional and let cards/buttons fill available width with the documented padding values.
