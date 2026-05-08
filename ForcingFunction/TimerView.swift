//
//  TimerView.swift
//  ForcingFunction
//
//  Calendar + Timer focus screen — Variant 4 design.
//  Left strip : scrollable 24-hour timeline. Block top = now (live).
//               Drag the bottom edge to resize duration.
//  Right panel: MM:SS card — drag the digits up/down to set duration (idle only).
//               Both sides write to viewModel.selectedMinutes.
//

import SwiftUI
import UIKit
import Combine

struct TimerView: View {

    @ObservedObject var viewModel: FocusSessionStore
    @ObservedObject private var projectStore = ProjectStore.shared
    @State private var isSetupPresented = false

    // ── Duration drag bases (bottom handle on strip / digit drag on card)
    @State private var blockDurBase:         Double  = 25
    @State private var timerDigitDragBase:   Double  = 25
    @State private var isResizingBlock:      Bool    = false
    @State private var lastHandleTranslation: CGFloat = 0

    // ── Live "now" refreshed every 30 s
    @State private var nowDate: Date = Date()
    private let minuteTicker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    // ── Strip layout constants  (2.4 pt/min → 144 pt/hr)
    private let pxPerMin: CGFloat = 2.4
    private var hourH:    CGFloat { pxPerMin * 60 }
    private let stripW:   CGFloat = 110
    private let gutterW:  CGFloat = 44

    // ── "Sand" card colour  (#E8E3DA)
    private let sand = Color(red: 232 / 255, green: 227 / 255, blue: 218 / 255)

    // MARK: – Derived state

    private var nowMins: Double {
        let c = Calendar.current
        return Double(c.component(.hour, from: nowDate) * 60
                    + c.component(.minute, from: nowDate))
    }

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

    private var sessionNumber: Int {
        viewModel.currentSessionType == .work
            ? viewModel.completedPomodoros + 1
            : viewModel.completedPomodoros
    }

    private var mmStr: String { String(format: "%02d", max(0, viewModel.remainingSeconds) / 60) }
    private var ssStr: String { String(format: "%02d", max(0, viewModel.remainingSeconds) % 60) }

    private var todayStr: String {
        let m = max(0, viewModel.totalFocusMinutes)
        return m < 60 ? "\(m)m" : "\(m / 60)h \(m % 60)m"
    }

    private var goalStr: String {
        let g = max(1, viewModel.dailyFocusGoalMinutes)
        return "\(min(Int(Double(viewModel.totalFocusMinutes) / Double(g) * 100), 999))%"
    }

    /// Block top:
    ///   idle    → nowMins (live)
    ///   running / paused → actual session start (nowMins − elapsed)
    private var blockStartMins: Double {
        guard viewModel.timerState != .idle else { return nowMins }
        let elapsed = viewModel.selectedMinutes - Double(viewModel.remainingSeconds) / 60.0
        return nowMins - elapsed
    }

    private var timerSubline: String {
        let s = blockStartMins
        let e = s + viewModel.selectedMinutes
        return "\(fmtMins(s)) → \(fmtMins(e)) · \(Int(viewModel.selectedMinutes.rounded()))m"
    }

    private var primaryLabel: String {
        switch viewModel.timerState {
        case .running:   return "Pause"
        case .paused:    return "Resume"
        case .idle:      return "Start focus"
        case .completed: return "Next"
        }
    }

    private func primaryAction() {
        switch viewModel.timerState {
        case .running:         viewModel.pauseTimer()
        case .paused, .idle:   viewModel.startTimer()
        case .completed:       viewModel.startNextSession()
        }
    }

    // MARK: – Root layout

    var body: some View {
        ZStack {
            HC.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                hairline
                HStack(spacing: 0) {
                    calendarStrip
                    HC.line.frame(width: 1)
                    timerPanel
                }
                .frame(maxHeight: .infinity)
                hairline
                actionRow
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $isSetupPresented) { PomodoroSetupSheet(viewModel: viewModel) }
        .onAppear {
            nowDate            = Date()
            blockDurBase       = viewModel.selectedMinutes
            timerDigitDragBase = viewModel.selectedMinutes
        }
        .onReceive(minuteTicker) { nowDate = $0 }
        .onChange(of: viewModel.selectedMinutes) { _, v in
            // Only sync bases when an external source (stepper, setup sheet) changes
            // the value — NOT while the user is actively dragging the block handle.
            if viewModel.timerState == .idle && !isResizingBlock {
                blockDurBase       = v
                timerDigitDragBase = v
            }
        }
    }

    private var hairline: some View {
        Rectangle().fill(HC.line).frame(height: 1)
    }

    // MARK: – Header bar

    private var headerBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SESSION №\(sessionNumber)").hcMonoLabel()
                Text(titleText)
                    .font(HC.display(20))
                    .tracking(-0.8)
                    .foregroundStyle(HC.ink)
            }
            Spacer()
        }
    }

    // MARK: – Calendar strip

    private var calendarStrip: some View {
        let totalH  = CGFloat(24 * 60) * pxPerMin  // 3 456 pt
        let anchorY = CGFloat(nowMins) * pxPerMin

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                // The ZStack holds all visual layers; an overlaid VStack provides a
                // layout-positioned anchor (offset() only moves visually — scrollTo
                // needs a real layout position).
                ZStack(alignment: .topLeading) {
                    gridLayer(totalH: totalH)
                    blockLayer(totalH: totalH)
                    nowLayer(totalH: totalH)

                    // Anchor sits at the correct layout Y so scrollTo works
                    VStack(spacing: 0) {
                        Color.clear.frame(width: 1, height: anchorY)
                        Color.clear.frame(width: 1, height: 1).id("nowAnchor")
                    }
                    .allowsHitTesting(false)
                }
                .frame(width: stripW, height: totalH, alignment: .topLeading)
            }
            .frame(width: stripW)
            .scrollDisabled(isResizingBlock)
            .onAppear { scrollToNow(proxy) }
            .onChange(of: nowMins) { _, _ in scrollToNow(proxy) }
        }
    }

    private func scrollToNow(_ proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            proxy.scrollTo("nowAnchor", anchor: UnitPoint(x: 0, y: 0.38))
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo("nowAnchor", anchor: UnitPoint(x: 0, y: 0.38))
            }
        }
    }

    // Hour grid lines + labels
    @ViewBuilder
    private func gridLayer(totalH: CGFloat) -> some View {
        let hrLineColor   = Color(red: 224 / 255, green: 219 / 255, blue: 211 / 255)
        let halfLineColor = Color(red: 236 / 255, green: 232 / 255, blue: 226 / 255)

        Canvas { ctx, size in
            for h in 0..<24 {
                let y = CGFloat(h) * self.hourH
                var p1 = Path()
                p1.move(to: CGPoint(x: self.gutterW, y: y))
                p1.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p1, with: .color(hrLineColor), lineWidth: 0.5)

                var p2 = Path()
                p2.move(to: CGPoint(x: self.gutterW, y: y + self.hourH / 2))
                p2.addLine(to: CGPoint(x: size.width, y: y + self.hourH / 2))
                ctx.stroke(p2, with: .color(halfLineColor), lineWidth: 0.5)
            }
        }
        .frame(width: stripW, height: totalH)
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                ForEach(0..<24, id: \.self) { h in
                    Text(hourLabel(h))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(HC.muted)
                        .frame(width: gutterW - 10, alignment: .trailing)
                        .offset(x: 0, y: CGFloat(h) * hourH - 7)
                }
            }
            .frame(width: stripW, height: totalH, alignment: .topLeading)
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
    }

    // Session block
    //   • Top  = blockStartMins (nowMins when idle; session start when live)
    //   • Body is non-interactive (start is always "now")
    //   • Bottom handle = only interactive edge; resizes selectedMinutes
    //   • Elapsed fill shown while running
    @ViewBuilder
    private func blockLayer(totalH: CGFloat) -> some View {
        let isIdle     = viewModel.timerState == .idle
        let bStart     = blockStartMins
        let bDur       = viewModel.selectedMinutes
        let bTop       = CGFloat(bStart) * pxPerMin
        let bH         = max(20, CGFloat(bDur) * pxPerMin)
        let bW         = stripW - gutterW - 4
        let bCX        = gutterW + bW / 2
        let bCY        = bTop + bH / 2
        let elapsed    = viewModel.selectedMinutes - Double(viewModel.remainingSeconds) / 60.0
        let elapsedH   = isIdle ? CGFloat(0) : max(0, min(bH, CGFloat(elapsed) * pxPerMin))

        ZStack {
            Color.clear.frame(width: stripW, height: totalH)

            // Block body (never draggable — only the bottom handle is)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(HC.red.opacity(0.13))
                // Elapsed-progress fill
                if elapsedH > 0 {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(HC.red.opacity(0.28))
                        .frame(height: elapsedH)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .frame(width: bW, height: bH)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(HC.red, lineWidth: 1.5)
            )
            .position(x: bCX, y: bCY)
            .allowsHitTesting(false)

            // Time label inside block
            if bH > 30 {
                VStack(alignment: .leading, spacing: 2) {
                    Text(fmtMins(bStart))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(HC.red)
                    if bH > 52 {
                        Text("\(Int(bDur.rounded()))m")
                            .font(.system(size: 9))
                            .foregroundStyle(HC.red.opacity(0.7))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 8)
                .frame(width: bW, height: bH, alignment: .topLeading)
                .position(x: bCX, y: bCY)
                .allowsHitTesting(false)
            }

            // Bottom resize handle — visible & interactive when idle.
            // Larger hit target + minimumDistance: 0 so the high-priority gesture
            // preempts the parent ScrollView's pan immediately on touch (otherwise
            // the strip scrolls before the handle wins). Bottom edge tracks the
            // finger 1:1 along the timeline (translation / pxPerMin minutes).
            if isIdle {
                ZStack {
                    Capsule()
                        .fill(HC.red.opacity(isResizingBlock ? 0.95 : 0.6))
                        .frame(width: isResizingBlock ? 28 : 20, height: 4)
                        .animation(.easeOut(duration: 0.12), value: isResizingBlock)
                }
                .frame(width: bW, height: 36)
                .contentShape(Rectangle())
                .position(x: bCX, y: bTop + bH)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            if !isResizingBlock {
                                isResizingBlock       = true
                                lastHandleTranslation = 0
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                            // Incremental delta — avoids any compounding regardless of
                            // how onChange(of: selectedMinutes) fires during the drag.
                            let currentT  = v.translation.height
                            let deltaT    = currentT - lastHandleTranslation
                            lastHandleTranslation = currentT
                            let deltaMins = Double(deltaT) / Double(pxPerMin)
                            let d = max(5, min(240, viewModel.selectedMinutes + deltaMins))
                            viewModel.setTimeFromMinutes(d)
                        }
                        .onEnded { _ in
                            isResizingBlock       = false
                            lastHandleTranslation = 0
                            blockDurBase          = viewModel.selectedMinutes
                            timerDigitDragBase    = viewModel.selectedMinutes
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                )
            }
        }
    }

    // Red "now" line + left dot
    @ViewBuilder
    private func nowLayer(totalH: CGFloat) -> some View {
        let y = CGFloat(nowMins) * pxPerMin
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(HC.red)
                .frame(width: stripW - gutterW, height: 2)
                .offset(x: gutterW, y: y - 1)
            Circle()
                .fill(HC.red)
                .frame(width: 8, height: 8)
                .offset(x: gutterW - 4, y: y - 4)
        }
        .frame(width: stripW, height: totalH, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    // MARK: – Timer panel (right side)

    private var timerPanel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                timerCard
                statsRow
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var timerCard: some View {
        let isIdle = viewModel.timerState == .idle

        return VStack(alignment: .leading, spacing: 0) {
            // "REMAINING" label + pomodoro badge
            HStack {
                Text("REMAINING").hcMonoLabel(size: 9)
                Spacer()
            }
            .padding(.bottom, 6)

            // Big condensed digits
            // When idle: vertical drag sets duration (up = more, down = less)
            HStack(spacing: 0) {
                Text(mmStr).foregroundStyle(HC.ink)
                Text(":")
                    .foregroundStyle(HC.red)
                    .padding(.bottom, 2)
                Text(ssStr).foregroundStyle(HC.ink)
            }
            .font(.custom("HelveticaNeue-CondensedBlack", size: 72))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                isIdle ?
                DragGesture(minimumDistance: 6)
                    .onChanged { v in
                        // drag up (negative height) = more time; ~7 pt = 1 min
                        let d = max(5, min(240,
                            timerDigitDragBase - Double(v.translation.height) * 0.15))
                        viewModel.setTimeFromMinutes(d)
                    }
                    .onEnded { _ in
                        timerDigitDragBase = viewModel.selectedMinutes
                        blockDurBase       = viewModel.selectedMinutes
                    }
                : nil
            )

            // Stepper row (idle only) — primary tap affordance; drag still works
            if isIdle {
                HStack(spacing: 8) {
                    stepperButton(delta: -5)
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 7, weight: .semibold))
                        Text("drag or tap")
                            .font(.system(size: 8, weight: .medium))
                            .tracking(0.5)
                    }
                    .foregroundStyle(HC.muted.opacity(0.45))
                    Spacer()
                    stepperButton(delta: +5)
                }
                .padding(.top, 6)
            }

            // "HH:MM → HH:MM · Nm"
            Text(timerSubline)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(HC.muted)
                .padding(.top, isIdle ? 4 : 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var statsRow: some View {
        HStack(spacing: 6) {
            statCell(label: "TODAY", value: todayStr)
            statCell(label: "GOAL",  value: goalStr)
        }
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(HC.muted)
            Text(value)
                .font(.custom("HelveticaNeue-CondensedBlack", size: 18))
                .foregroundStyle(HC.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sand, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: – Action row

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button(action: primaryAction) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.timerState == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(primaryLabel)
                        .font(HC.text(15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(HC.red, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .buttonStyle(.plain)

            if viewModel.timerState != .idle {
                Button { viewModel.resetTimer() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(HC.ink)
                        .frame(width: 48, height: 48)
                        .background(sand, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Button { isSetupPresented = true } label: {
                    Text("SETUP")
                        .font(HC.mono(10, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(HC.ink)
                        .frame(width: 70, height: 48)
                        .background(sand, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: – Stepper button

    private func stepperButton(delta: Int) -> some View {
        Button {
            let newVal = max(5, min(240, viewModel.selectedMinutes + Double(delta)))
            viewModel.setTimeFromMinutes(newVal)
            timerDigitDragBase = viewModel.selectedMinutes
            blockDurBase       = viewModel.selectedMinutes
        } label: {
            Text(delta > 0 ? "+\(delta)" : "\(delta)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(HC.ink)
                .frame(width: 40, height: 26)
                .background(HC.line.opacity(0.6), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: – Helpers

    private func hourLabel(_ h: Int) -> String {
        switch h {
        case 0:  return "12am"
        case 12: return "12pm"
        default: return h < 12 ? "\(h)am" : "\(h - 12)pm"
        }
    }

    private func fmtMins(_ totalMins: Double) -> String {
        let h  = Int(totalMins) / 60 % 24
        let m  = Int(totalMins) % 60
        let hh = h % 12 == 0 ? 12 : h % 12
        return "\(hh):\(String(format: "%02d", m)) \(h >= 12 ? "PM" : "AM")"
    }
}

#Preview {
    TimerView(viewModel: FocusSessionStore())
}
