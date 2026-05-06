//
//  HCDesign.swift
//  ForcingFunction
//
//  Design tokens for the Hour Cards redesign.
//  See design-reference/design_handoff_hour_cards/README.md for the source spec.
//

import SwiftUI

enum HC {

    // MARK: Colors

    static let bg     = Color(red: 0xEF/255.0, green: 0xEA/255.0, blue: 0xE0/255.0) // #EFEAE0 warm off-white
    static let card   = Color(red: 0xFF/255.0, green: 0xFC/255.0, blue: 0xF5/255.0) // #FFFCF5 cream
    static let ink    = Color(red: 0x19/255.0, green: 0x17/255.0, blue: 0x14/255.0) // #191714
    static let muted  = Color(red: 0x8A/255.0, green: 0x84/255.0, blue: 0x75/255.0) // #8A8475
    static let line   = Color(red: 0xD8/255.0, green: 0xD2/255.0, blue: 0xC2/255.0) // #D8D2C2
    static let red    = Color(red: 0xE5/255.0, green: 0x4B/255.0, blue: 0x2A/255.0) // #E54B2A tomato
    static let blue   = Color(red: 0x2E/255.0, green: 0x4D/255.0, blue: 0xDB/255.0) // #2E4DDB
    static let yellow = Color(red: 0xF5/255.0, green: 0xD0/255.0, blue: 0x2C/255.0) // #F5D02C

    // MARK: Spacing

    static let pagePaddingH: CGFloat = 20
    static let topSafe: CGFloat = 60
    static let cardPadding: CGFloat = 18
    static let blockGap: CGFloat = 20

    // MARK: Radii

    enum Radius {
        static let hero: CGFloat = 22
        static let card: CGFloat = 18
        static let smallCard: CGFloat = 14
        static let pill: CGFloat = 18
        static let button: CGFloat = 30
        static let tag: CGFloat = 8
    }

    // MARK: Typography

    /// Heavy display — big numerals & headlines. Helvetica Neue Black, tight tracking.
    static func display(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        .custom("HelveticaNeue", size: size).weight(weight)
    }

    /// Body / UI text — system sans.
    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Mono — small caps labels, timestamps, durations.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: Shadows

    static func heroShadow<V: View>(_ view: V) -> some View {
        view.shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 12)
    }
}

// MARK: - Reusable view modifiers

extension View {
    /// Cream card surface with hairline border. Optional subtle hero shadow.
    func hcCard(radius: CGFloat = HC.Radius.card, hero: Bool = false) -> some View {
        self
            .background(HC.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(HC.line, lineWidth: hero ? 0 : 1)
            )
            .shadow(color: hero ? Color.black.opacity(0.04) : .clear,
                    radius: hero ? 15 : 0, x: 0, y: hero ? 12 : 0)
    }

    /// Mono small-caps label style (e.g. "REMAINING", "SESSION №24").
    func hcMonoLabel(size: CGFloat = 10) -> some View {
        self
            .font(HC.mono(size, weight: .medium))
            .tracking(1.2)
            .foregroundStyle(HC.muted)
    }
}
