//
//  ProductIdMenu.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import SwiftUI

struct ProductIdMenu: View {
    @Binding var productIds: [String]
    @Binding var selectedProductId: String
    @State private var showProductSearch = false
    @StateObject private var productService: ProductService
    @StateObject private var oauthManager = OAuthManager()

    init(productIds: Binding<[String]>, selectedProductId: Binding<String>) {
        _productIds = productIds
        _selectedProductId = selectedProductId
        let service = ProductService(accessToken: nil)
        _productService = StateObject(wrappedValue: service)
    }

    var body: some View {
        ScrollView([.horizontal], showsIndicators: false) {
            HStack(alignment: .top, spacing: 6) {
                ForEach(productIds, id: \.self) { productId in
                    ProductIdCard(
                        productId: productId,
                        productIds: $productIds,
                        selectedProductId: $selectedProductId
                    )
                }

                Button(action: {
                    showProductSearch = true
                }) {
                    HStack(spacing: TerminalTheme.paddingTiny) {
                        Text("+")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .bold))
                        Text("ADD")
                            .font(TerminalTheme.monospaced(size: TerminalTheme.fontSizeSmall, weight: .bold))
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
        .padding([.leading, .trailing], 4)
        .sheet(isPresented: $showProductSearch) {
            ProductSearchView(
                productService: productService,
                isPresented: $showProductSearch,
                onSelect: { productId in
                    if !productIds.contains(productId) {
                        productIds.append(productId)
                        selectedProductId = productId
                    }
                },
                existingProductIds: productIds
            )
        }
        .onAppear {
            oauthManager.loadTokens()
            if let token = oauthManager.accessToken {
                productService.updateToken(token)
                productService.setTokenRefreshHandler { [weak oauthManager] in
                    guard let oauthManager = oauthManager else { return nil }
                    let success = await oauthManager.refreshAccessToken()
                    return success ? oauthManager.accessToken : nil
                }
            }
        }
        .onChange(of: oauthManager.accessToken) { _, newToken in
            productService.updateToken(newToken)
        }
    }
}
