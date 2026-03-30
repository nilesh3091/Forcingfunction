//
//  HUDChrome.swift
//  ForcingFunction
//
//  Minimal grid + chrome for a dark “mission-control” / HUD-style layer.
//

import SwiftUI

/// Faint square grid (technical readout feel) over the main canvas.
struct HUDGridBackground: View {
    var lineColor: Color
    var spacing: CGFloat = 28
    var lineWidth: CGFloat = 0.5

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / spacing)) + 1
            let rows = Int(ceil(size.height / spacing)) + 1
            var path = Path()
            for i in 0...cols {
                let x = CGFloat(i) * spacing
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for j in 0...rows {
                let y = CGFloat(j) * spacing
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(lineColor), lineWidth: lineWidth)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Soft edge darkening so the center readout stays the focal point.
struct HUDEdgeVignette: View {
    var color: Color

    var body: some View {
        LinearGradient(
            colors: [
                color.opacity(0.55),
                color.opacity(0.08),
                color.opacity(0.45)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
