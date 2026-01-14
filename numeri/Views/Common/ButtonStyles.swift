//
//  ButtonStyles.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import SwiftUI

struct PillButtonStyle: ButtonStyle {
    var backgroundColor: Color = .gray
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundColor(.white)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(backgroundColor)
            .cornerRadius(20)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct RoundButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(Color.gray)
            .cornerRadius(20)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

