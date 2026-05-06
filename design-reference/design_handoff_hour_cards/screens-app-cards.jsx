// App redesign — Direction D: Hour Cards
// Warm off-white surface, cards stack with playful scale + horizontal bar timer.
// Maximalist confidence in type and color blocks. No dial.

const HC_BG = '#EFEAE0';
const HC_CARD = '#FFFCF5';
const HC_INK = '#191714';
const HC_MUTED = '#8A8475';
const HC_LINE = '#D8D2C2';
const HC_RED = '#E54B2A';     // hot tomato
const HC_BLUE = '#2E4DDB';    // deep electric
const HC_YEL = '#F5D02C';

const HC_DISPLAY = '"Helvetica Neue",Helvetica,Arial Black,sans-serif';
const HC_TEXT = '-apple-system,"SF Pro Text",system-ui,sans-serif';
const HC_MONO = '"SFMono-Regular",ui-monospace,Menlo,monospace';

function HCShell({ children }) {
  return <IOSDevice width={340} height={736}>{children}</IOSDevice>;
}

function HCTabBar({ active = 'focus' }) {
  const tabs = [
    { id: 'focus', label: 'Focus', glyph: '●' },
    { id: 'log', label: 'Log', glyph: '◍' },
    { id: 'shape', label: 'Shape', glyph: '◐' },
    { id: 'tune', label: 'Tune', glyph: '◇' },
  ];
  return (
    <div style={{
      borderTop: `1px solid ${HC_LINE}`, background: HC_BG,
      display: 'grid', gridTemplateColumns: 'repeat(4,1fr)',
      padding: '10px 12px 22px',
    }}>
      {tabs.map(t => (
        <div key={t.id} style={{
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
          fontFamily: HC_TEXT, fontSize: 11,
          color: active === t.id ? HC_INK : HC_MUTED,
          fontWeight: active === t.id ? 700 : 500,
        }}>
          <div style={{ fontSize: 14, color: active === t.id ? HC_RED : HC_MUTED }}>{t.glyph}</div>
          {t.label}
        </div>
      ))}
    </div>
  );
}

// 1 — FOCUS (timer): big stacked card with horizontal progress bar
function HCTimer() {
  return (
    <HCShell>
      <div style={{ height: '100%', background: HC_BG, display: 'flex', flexDirection: 'column' }}>
        {/* Header */}
        <div style={{ padding: '60px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <div style={{ fontFamily: HC_MONO, fontSize: 10, color: HC_MUTED, letterSpacing: 1.2 }}>SESSION №24</div>
            <div style={{ fontFamily: HC_DISPLAY, fontSize: 32, color: HC_INK, letterSpacing: -1.4, lineHeight: 1, fontWeight: 800, marginTop: 4 }}>Pomodoro 1.</div>
          </div>
          <div style={{
            background: HC_INK, color: HC_BG, fontFamily: HC_MONO, fontSize: 10,
            padding: '6px 10px', letterSpacing: 1, fontWeight: 700,
          }}>NBME</div>
        </div>

        {/* Hero card */}
        <div style={{ padding: '20px 20px 0' }}>
          <div style={{
            background: HC_CARD, border: `1px solid ${HC_LINE}`, borderRadius: 22,
            padding: '24px 22px 22px', position: 'relative',
            boxShadow: '0 12px 30px rgba(0,0,0,0.04)',
          }}>
            {/* Folded corner accent */}
            <div style={{
              position: 'absolute', top: 16, right: 16,
              width: 38, height: 38, borderRadius: '50%', background: HC_RED,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: '#fff', fontFamily: HC_DISPLAY, fontSize: 13, fontWeight: 800,
              fontVariantNumeric: 'tabular-nums',
            }}>1/4</div>

            <div style={{ fontFamily: HC_MONO, fontSize: 10, color: HC_MUTED, letterSpacing: 1.2 }}>REMAINING</div>
            <div style={{ fontFamily: HC_DISPLAY, fontSize: 116, fontWeight: 900, lineHeight: 0.86, letterSpacing: -6.5, color: HC_INK, fontVariantNumeric: 'tabular-nums', marginTop: 4 }}>
              30<span style={{ color: HC_RED }}>:</span>00
            </div>
            <div style={{ fontFamily: HC_TEXT, fontSize: 13, color: HC_MUTED, marginTop: 6 }}>
              ends 14:30 · break 5m
            </div>

            {/* Horizontal bar */}
            <div style={{ marginTop: 22, height: 14, background: HC_BG, borderRadius: 7, position: 'relative', border: `1px solid ${HC_LINE}` }}>
              <div style={{ position: 'absolute', left: 2, top: 2, bottom: 2, width: '0%', background: HC_RED, borderRadius: 5 }} />
              {/* tick markers */}
              {[0.25, 0.5, 0.75].map(p => (
                <div key={p} style={{ position: 'absolute', left: `${p * 100}%`, top: -4, bottom: -4, width: 1, background: HC_LINE }} />
              ))}
            </div>
          </div>
        </div>

        {/* Stat strip */}
        <div style={{ padding: '14px 20px 0', display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
          {[
            ['TODAY', '0m', HC_INK],
            ['GOAL', '0%', HC_INK],
            ['STREAK', '19d', HC_RED],
          ].map(([k, v, c]) => (
            <div key={k} style={{ background: HC_CARD, border: `1px solid ${HC_LINE}`, borderRadius: 14, padding: '12px 14px' }}>
              <div style={{ fontFamily: HC_MONO, fontSize: 9, color: HC_MUTED, letterSpacing: 1 }}>{k}</div>
              <div style={{ fontFamily: HC_DISPLAY, fontSize: 22, color: c, fontWeight: 800, marginTop: 2, letterSpacing: -0.6, fontVariantNumeric: 'tabular-nums' }}>{v}</div>
            </div>
          ))}
        </div>

        <div style={{ flex: 1 }} />

        {/* Action */}
        <div style={{ padding: '0 20px 16px', display: 'flex', gap: 10 }}>
          <div style={{
            flex: 1, height: 60, background: HC_RED, borderRadius: 30,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
            color: '#fff', fontFamily: HC_DISPLAY, fontSize: 18, fontWeight: 800, letterSpacing: -0.3,
          }}>▶ Start focus</div>
          <div style={{
            width: 60, height: 60, borderRadius: 30, border: `1px solid ${HC_LINE}`, background: HC_CARD,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontFamily: HC_MONO, fontSize: 11, color: HC_INK, letterSpacing: 0.5,
          }}>SETUP</div>
        </div>
        <HCTabBar active="focus" />
      </div>
    </HCShell>
  );
}

// 2 — LOG (history): cards listed by day, color blocks for tag
function HCHistory() {
  const days = [
    { day: 'TUE 29', total: '1h 12m', sessions: [
      { tag: 'NBME', dur: '45m', t: '09:00', c: HC_RED },
      { tag: 'NBME', dur: '27m', t: '13:30', c: HC_RED },
    ]},
    { day: 'MON 28', total: '2h 15m', sessions: [
      { tag: 'PHARM', dur: '90m', t: '10:00', c: HC_BLUE },
      { tag: 'NBME', dur: '45m', t: '15:00', c: HC_RED },
    ]},
  ];
  return (
    <HCShell>
      <div style={{ height: '100%', background: HC_BG, display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '60px 20px 0' }}>
          <div style={{ fontFamily: HC_MONO, fontSize: 10, color: HC_MUTED, letterSpacing: 1.2 }}>JOURNAL</div>
          <div style={{ fontFamily: HC_DISPLAY, fontSize: 44, color: HC_INK, letterSpacing: -2, fontWeight: 900, lineHeight: 1, marginTop: 4 }}>
            The log.
          </div>
        </div>

        {/* Range pill row */}
        <div style={{ padding: '20px 20px 0', display: 'flex', gap: 6 }}>
          {[['Day', true],['Week', false],['Month', false],['All', false]].map(([l, sel]) => (
            <div key={l} style={{
              padding: '8px 14px', borderRadius: 18,
              background: sel ? HC_INK : HC_CARD,
              color: sel ? HC_BG : HC_INK,
              border: sel ? 'none' : `1px solid ${HC_LINE}`,
              fontFamily: HC_TEXT, fontSize: 12, fontWeight: 600,
            }}>{l}</div>
          ))}
        </div>

        {/* Day cards */}
        <div style={{ padding: '18px 20px 0', display: 'flex', flexDirection: 'column', gap: 12, flex: 1, overflow: 'hidden' }}>
          {days.map(d => (
            <div key={d.day} style={{ background: HC_CARD, border: `1px solid ${HC_LINE}`, borderRadius: 18, padding: '16px 18px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 12 }}>
                <div style={{ fontFamily: HC_DISPLAY, fontSize: 22, color: HC_INK, fontWeight: 900, letterSpacing: -0.6 }}>{d.day}</div>
                <div style={{ fontFamily: HC_MONO, fontSize: 12, color: HC_MUTED, letterSpacing: 0.5, fontWeight: 700 }}>{d.total}</div>
              </div>
              {d.sessions.map((s, i) => (
                <div key={i} style={{
                  display: 'flex', alignItems: 'center', gap: 12,
                  padding: '8px 0', borderTop: i > 0 ? `1px dashed ${HC_LINE}` : 'none',
                }}>
                  <div style={{ width: 6, height: 22, background: s.c, borderRadius: 1 }} />
                  <div style={{ flex: 1 }}>
                    <div style={{ fontFamily: HC_DISPLAY, fontSize: 14, color: HC_INK, fontWeight: 800, letterSpacing: 0.2 }}>{s.tag}</div>
                    <div style={{ fontFamily: HC_MONO, fontSize: 10, color: HC_MUTED, letterSpacing: 0.5, marginTop: 1 }}>{s.t}</div>
                  </div>
                  <div style={{ fontFamily: HC_DISPLAY, fontSize: 16, color: HC_INK, fontWeight: 800, fontVariantNumeric: 'tabular-nums', letterSpacing: -0.3 }}>{s.dur}</div>
                </div>
              ))}
            </div>
          ))}
        </div>

        <HCTabBar active="log" />
      </div>
    </HCShell>
  );
}

// 3 — SHAPE (stats) — bold colored blocks, big numbers
function HCStats() {
  const week = [0.4, 0.7, 0.55, 0.9, 0.3, 0.0, 0.6];
  return (
    <HCShell>
      <div style={{ height: '100%', background: HC_BG, display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '60px 20px 0' }}>
          <div style={{ fontFamily: HC_MONO, fontSize: 10, color: HC_MUTED, letterSpacing: 1.2 }}>YOUR ARC</div>
          <div style={{ fontFamily: HC_DISPLAY, fontSize: 44, color: HC_INK, letterSpacing: -2, fontWeight: 900, lineHeight: 1, marginTop: 4 }}>
            Shape.
          </div>
        </div>

        {/* Big block */}
        <div style={{ padding: '20px 20px 0' }}>
          <div style={{
            background: HC_RED, color: '#fff', borderRadius: 22, padding: '20px 22px',
            position: 'relative',
          }}>
            <div style={{ fontFamily: HC_MONO, fontSize: 10, opacity: 0.85, letterSpacing: 1.2 }}>THIS WEEK</div>
            <div style={{ fontFamily: HC_DISPLAY, fontSize: 76, fontWeight: 900, lineHeight: 0.9, letterSpacing: -3.5, marginTop: 4, fontVariantNumeric: 'tabular-nums' }}>
              11h 47m
            </div>
            <div style={{ fontFamily: HC_TEXT, fontSize: 13, opacity: 0.9, marginTop: 6 }}>
              ↑ 2h 12m vs last week
            </div>
          </div>
        </div>

        {/* Bars */}
        <div style={{ padding: '18px 20px 0' }}>
          <div style={{ background: HC_CARD, border: `1px solid ${HC_LINE}`, borderRadius: 18, padding: '16px 18px' }}>
            <div style={{ display: 'flex', alignItems: 'flex-end', gap: 10, height: 110 }}>
              {week.map((v, i) => (
                <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
                  <div style={{ flex: 1, width: '100%', display: 'flex', alignItems: 'flex-end' }}>
                    <div style={{
                      width: '100%',
                      height: `${Math.max(v * 100, 2)}%`,
                      background: i === 3 ? HC_RED : i === 5 ? HC_LINE : HC_INK,
                      borderRadius: 4,
                    }} />
                  </div>
                  <div style={{ fontFamily: HC_MONO, fontSize: 9, color: i === 3 ? HC_RED : HC_MUTED, fontWeight: 700, letterSpacing: 0.5 }}>{['M','T','W','T','F','S','S'][i]}</div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Mini stats */}
        <div style={{ padding: '12px 20px 0', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {[
            ['BEST DAY', 'Thu', HC_INK],
            ['BEST HOUR', '9 am', HC_INK],
            ['AVG SESSION', '42m', HC_INK],
            ['LONGEST', '2h 28m', HC_BLUE],
          ].map(([k, v, c]) => (
            <div key={k} style={{ background: HC_CARD, border: `1px solid ${HC_LINE}`, borderRadius: 14, padding: '12px 14px' }}>
              <div style={{ fontFamily: HC_MONO, fontSize: 9, color: HC_MUTED, letterSpacing: 1 }}>{k}</div>
              <div style={{ fontFamily: HC_DISPLAY, fontSize: 22, color: c, fontWeight: 800, marginTop: 2, letterSpacing: -0.6 }}>{v}</div>
            </div>
          ))}
        </div>

        <div style={{ flex: 1 }} />
        <HCTabBar active="shape" />
      </div>
    </HCShell>
  );
}

// 4 — TUNE (settings)
function HCSettings() {
  const Section = ({ title, rows, accent }) => (
    <div style={{ marginTop: 18 }}>
      <div style={{ fontFamily: HC_MONO, fontSize: 10, color: HC_MUTED, letterSpacing: 1.2, padding: '0 20px 8px' }}>{title}</div>
      <div style={{ background: HC_CARD, marginInline: 20, borderRadius: 18, border: `1px solid ${HC_LINE}` }}>
        {rows.map(([k, v], i) => (
          <div key={k} style={{
            display: 'flex', justifyContent: 'space-between', alignItems: 'center',
            padding: '14px 18px',
            borderTop: i > 0 ? `1px solid ${HC_LINE}` : 'none',
          }}>
            <div style={{ fontFamily: HC_TEXT, fontSize: 15, color: HC_INK, fontWeight: 500 }}>{k}</div>
            <div style={{
              fontFamily: HC_DISPLAY, fontSize: 14, color: accent, fontWeight: 800, letterSpacing: -0.2,
              padding: '4px 10px', background: 'rgba(229,75,42,0.08)', borderRadius: 8,
            }}>{v}</div>
          </div>
        ))}
      </div>
    </div>
  );
  return (
    <HCShell>
      <div style={{ height: '100%', background: HC_BG, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        <div style={{ padding: '60px 20px 0' }}>
          <div style={{ fontFamily: HC_MONO, fontSize: 10, color: HC_MUTED, letterSpacing: 1.2 }}>PREFERENCES</div>
          <div style={{ fontFamily: HC_DISPLAY, fontSize: 44, color: HC_INK, letterSpacing: -2, fontWeight: 900, lineHeight: 1, marginTop: 4 }}>
            Tune.
          </div>
        </div>
        <Section title="SESSION" accent={HC_RED} rows={[['Pomodoro','45m'],['Short break','5m'],['Long break','15m'],['Cycle','×4']]} />
        <Section title="GOAL" accent={HC_BLUE} rows={[['Daily target','1h'],['Reminder','8:00 am']]} />
        <Section title="LOOK" accent={HC_INK} rows={[['Mode','Light'],['Accent','Tomato']]} />
        <div style={{ flex: 1 }} />
        <HCTabBar active="tune" />
      </div>
    </HCShell>
  );
}

Object.assign(window, { HCTimer, HCHistory, HCStats, HCSettings });
