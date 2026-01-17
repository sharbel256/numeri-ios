//
//  TerminalTheme.swift
//  numeri
//
//  Bloomberg Terminal-inspired design system
//

import SwiftUI

struct TerminalTheme {
    // Colors - Bloomberg Terminal inspired
    static let background = Color(red: 0.05, green: 0.05, blue: 0.05) // Very dark gray, almost black
    static let surface = Color(red: 0.1, green: 0.1, blue: 0.1) // Slightly lighter for cards
    static let border = Color(red: 0.3, green: 0.3, blue: 0.3) // Medium gray for borders
    static let textPrimary = Color(red: 0.9, green: 0.9, blue: 0.9) // Light gray text
    static let textSecondary = Color(red: 0.6, green: 0.6, blue: 0.6) // Medium gray text
    
    // Terminal colors
    static let green = Color(red: 0.0, green: 1.0, blue: 0.0) // Bright green
    static let amber = Color(red: 1.0, green: 0.84, blue: 0.0) // Amber/yellow
    static let red = Color(red: 1.0, green: 0.0, blue: 0.0) // Bright red
    static let cyan = Color(red: 0.0, green: 1.0, blue: 1.0) // Cyan
    static let blue = Color(red: 0.0, green: 0.5, blue: 1.0) // Terminal blue
    
    // Spacing - minimal padding
    static let paddingTiny: CGFloat = 2
    static let paddingSmall: CGFloat = 4
    static let paddingMedium: CGFloat = 6
    static let paddingLarge: CGFloat = 8
    static let paddingXLarge: CGFloat = 12
    
    // Fonts - monospaced for terminal feel (increased sizes)
    static func monospaced(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    
    // Standard font sizes (increased from original)
    static let fontSizeTiny: CGFloat = 10
    static let fontSizeSmall: CGFloat = 12
    static let fontSizeMedium: CGFloat = 14
    static let fontSizeLarge: CGFloat = 16
    
    // Border style
    static func borderStyle() -> some View {
        Rectangle()
            .stroke(TerminalTheme.border, lineWidth: 1)
    }
}
