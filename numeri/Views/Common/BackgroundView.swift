//
//  BackgroundView.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import SwiftUI

struct BackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [colorScheme == .dark ? .black : .white]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

