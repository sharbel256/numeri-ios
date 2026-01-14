//
//  LoginPromptView.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import SwiftUI

struct LoginPromptView: View {
    @Binding var showCredentialsAlert: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Coinbase Login Required")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Please log in with Coinbase in the Settings tab to view the order book.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Go to Settings") {
                showCredentialsAlert = true
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

