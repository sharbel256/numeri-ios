//
//  ButtonStyles.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import SwiftUI

struct TerminalButtonStyle: ButtonStyle {
    var backgroundColor: Color = TerminalTheme.surface
    var foregroundColor: Color = TerminalTheme.textPrimary
    var borderColor: Color = TerminalTheme.border

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TerminalTheme.monospaced(size: 12, weight: .medium))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, TerminalTheme.paddingMedium)
            .padding(.vertical, TerminalTheme.paddingSmall)
            .background(backgroundColor)
            .overlay(
                Rectangle()
                    .stroke(borderColor, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct TerminalActionButtonStyle: ButtonStyle {
    var color: Color = TerminalTheme.blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TerminalTheme.monospaced(size: 12, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, TerminalTheme.paddingMedium)
            .padding(.vertical, TerminalTheme.paddingSmall)
            .background(color)
            .overlay(
                Rectangle()
                    .stroke(TerminalTheme.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// Legacy support
struct PillButtonStyle: ButtonStyle {
    var backgroundColor: Color = TerminalTheme.surface

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TerminalTheme.monospaced(size: 12))
            .foregroundColor(TerminalTheme.textPrimary)
            .padding(.horizontal, TerminalTheme.paddingMedium)
            .padding(.vertical, TerminalTheme.paddingSmall)
            .background(backgroundColor)
            .overlay(
                Rectangle()
                    .stroke(TerminalTheme.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct RoundButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TerminalTheme.monospaced(size: 12))
            .foregroundColor(TerminalTheme.textPrimary)
            .padding(.horizontal, TerminalTheme.paddingMedium)
            .padding(.vertical, TerminalTheme.paddingSmall)
            .background(TerminalTheme.surface)
            .overlay(
                Rectangle()
                    .stroke(TerminalTheme.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
