//
//  ProductSearchView.swift
//  numeri
//
//  Created by Sharbel Homa on 7/5/25.
//

import SwiftUI
import AuthenticationServices

struct ProductSearchView: View {
    @ObservedObject var productService: ProductService
    @Binding var isPresented: Bool
    let onSelect: (String) -> Void
    let existingProductIds: [String]

    @State private var searchText = ""
    @State private var hasSearched = false
    @StateObject private var oauthManager = OAuthManager()
    
    private var isScopeError: Bool {
        guard let error = productService.error else { return false }
        let errorLower = error.lowercased()
        return errorLower.contains("scope") || errorLower.contains("missing required") || errorLower.contains("permission")
    }

    private var filteredProducts: [Product] {
        if searchText.isEmpty {
            return productService.products
        }
        return productService.products.filter { product in
            product.productId.lowercased().contains(searchText.lowercased()) ||
                product.baseDisplaySymbol.lowercased().contains(searchText.lowercased()) ||
                product.quoteDisplaySymbol.lowercased().contains(searchText.lowercased()) ||
                product.baseName.lowercased().contains(searchText.lowercased()) ||
                product.quoteName.lowercased().contains(searchText.lowercased())
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Text("🔍")
                        .font(.system(size: 12))
                        .foregroundColor(TerminalTheme.textSecondary)
                    TextField("SEARCH PRODUCTS (E.G., BTC, USD, BITCOIN)", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(TerminalTheme.monospaced(size: 10))
                        .foregroundColor(TerminalTheme.textPrimary)
                        .onChange(of: searchText) { _, _ in
                            hasSearched = true
                        }

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Text("✕")
                                .font(TerminalTheme.monospaced(size: 10, weight: .bold))
                                .foregroundColor(TerminalTheme.textSecondary)
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, TerminalTheme.paddingMedium)
                .padding(.vertical, TerminalTheme.paddingMedium)
                .background(TerminalTheme.surface)
                .overlay(TerminalTheme.borderStyle())
                .padding(.horizontal, TerminalTheme.paddingSmall)
                .padding(.top, TerminalTheme.paddingSmall)

                // Content
                if productService.isLoading {
                    Spacer()
                    VStack(spacing: TerminalTheme.paddingSmall) {
                        ProgressView()
                            .tint(TerminalTheme.cyan)
                        Text("LOADING PRODUCTS...")
                            .font(TerminalTheme.monospaced(size: 10))
                            .foregroundColor(TerminalTheme.textSecondary)
                    }
                    Spacer()
                } else if let error = productService.error {
                    Spacer()
                    VStack(spacing: TerminalTheme.paddingMedium) {
                        Text("⚠")
                            .font(.system(size: 30))
                            .foregroundColor(TerminalTheme.amber)
                        Text(error.uppercased())
                            .font(TerminalTheme.monospaced(size: 10))
                            .foregroundColor(TerminalTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, TerminalTheme.paddingSmall)
                        
                        if isScopeError {
                            Text("RE-AUTHENTICATION REQUIRED")
                                .font(TerminalTheme.monospaced(size: 9, weight: .bold))
                                .foregroundColor(TerminalTheme.textPrimary)
                                .padding(.top, TerminalTheme.paddingSmall)
                            
                            Button(action: {
                                oauthManager.oauthError = nil
                                oauthManager.startOAuthFlow(presentationAnchor: WindowPresentationAnchor())
                            }) {
                                HStack {
                                    Text("🔑")
                                        .font(.system(size: 10))
                                    Text("RE-AUTHENTICATE")
                                        .font(TerminalTheme.monospaced(size: 9, weight: .bold))
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, TerminalTheme.paddingMedium)
                                .padding(.vertical, TerminalTheme.paddingSmall)
                                .background(TerminalTheme.cyan)
                                .overlay(
                                    Rectangle()
                                        .stroke(TerminalTheme.border, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer()
                } else if filteredProducts.isEmpty {
                    Spacer()
                    VStack(spacing: TerminalTheme.paddingSmall) {
                        Text("🔍")
                            .font(.system(size: 30))
                            .foregroundColor(TerminalTheme.textSecondary)
                        Text(hasSearched ? "NO PRODUCTS FOUND" : "START TYPING TO SEARCH PRODUCTS")
                            .font(TerminalTheme.monospaced(size: 10))
                            .foregroundColor(TerminalTheme.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: TerminalTheme.paddingSmall) {
                            ForEach(filteredProducts) { product in
                                ProductRow(
                                    product: product,
                                    isAlreadyAdded: existingProductIds.contains(product.productId),
                                    onSelect: {
                                        if !existingProductIds.contains(product.productId) {
                                            onSelect(product.productId)
                                            isPresented = false
                                        }
                                    }
                                )
                            }
                        }
                        .padding(TerminalTheme.paddingSmall)
                    }
                }
            }
            .background(TerminalTheme.background)
            .navigationTitle("ADD PRODUCT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("DONE") {
                        isPresented = false
                    }
                    .font(TerminalTheme.monospaced(size: 10, weight: .bold))
                }
            }
        }
        .task {
            oauthManager.loadTokens()
            if let token = oauthManager.accessToken {
                productService.updateToken(token)
                productService.setTokenRefreshHandler { [weak oauthManager] in
                    guard let oauthManager = oauthManager else { return nil }
                    let success = await oauthManager.refreshAccessToken()
                    return success ? oauthManager.accessToken : nil
                }
            }
            if productService.products.isEmpty {
                await productService.fetchProducts()
            }
        }
        .onChange(of: oauthManager.accessToken) { _, newToken in
            productService.updateToken(newToken)
            if newToken != nil && productService.products.isEmpty {
                Task {
                    await productService.fetchProducts()
                }
            }
        }
    }
}

struct ProductRow: View {
    let product: Product
    let isAlreadyAdded: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: TerminalTheme.paddingMedium) {
                VStack(alignment: .leading, spacing: TerminalTheme.paddingTiny) {
                    Text(product.displayName.uppercased())
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .semibold))
                        .foregroundColor(TerminalTheme.textPrimary)

                    HStack(spacing: TerminalTheme.paddingSmall) {
                        Text(product.baseName.uppercased())
                            .font(TerminalTheme.monospaced(size: 9))
                            .foregroundColor(TerminalTheme.textSecondary)
                        Text("•")
                            .font(TerminalTheme.monospaced(size: 9))
                            .foregroundColor(TerminalTheme.textSecondary)
                        Text(product.quoteName.uppercased())
                            .font(TerminalTheme.monospaced(size: 9))
                            .foregroundColor(TerminalTheme.textSecondary)
                    }
                }

                Spacer()

                if let price = product.price, let priceValue = Double(price) {
                    VStack(alignment: .trailing, spacing: TerminalTheme.paddingTiny) {
                        Text(formatPrice(priceValue))
                            .font(TerminalTheme.monospaced(size: 10, weight: .semibold))
                            .foregroundColor(TerminalTheme.textPrimary)

                        if let change24h = product.pricePercentageChange24h {
                            Text(change24h.uppercased())
                                .font(TerminalTheme.monospaced(size: 9))
                                .foregroundColor(change24h.hasPrefix("-") ? TerminalTheme.red : TerminalTheme.green)
                        }
                    }
                }

                if isAlreadyAdded {
                    Text("✓")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeMedium, weight: .bold))
                        .foregroundColor(TerminalTheme.green)
                } else {
                    Text("+")
                        .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeMedium, weight: .bold))
                        .foregroundColor(TerminalTheme.cyan)
                }
            }
            .padding(.horizontal, TerminalTheme.paddingSmall)
            .padding(.vertical, TerminalTheme.paddingSmall)
            .background(TerminalTheme.surface)
            .overlay(TerminalTheme.borderStyle())
        }
        .buttonStyle(.plain)
        .disabled(isAlreadyAdded)
        .opacity(isAlreadyAdded ? 0.6 : 1.0)
    }

    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "$%.2f", price)
        } else if price >= 1 {
            return String(format: "$%.4f", price)
        } else {
            return String(format: "$%.8f", price)
        }
    }
}
