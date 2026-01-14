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
    @State private var showAddProductAlert = false
    @State private var newProductId = ""
    
    var body: some View {
        ScrollView([.horizontal], showsIndicators: false) {
            HStack(alignment: .top) {
                ForEach(productIds, id: \.self) { productId in
                    VStack {
                        ProductIdCard(
                            productId: productId,
                            productIds: $productIds,
                            selectedProductId: $selectedProductId
                        )
                    }
                }
                
                Button(action: {
                    showAddProductAlert = true
                }) {
                    Text("+")
                }
                .buttonStyle(RoundButtonStyle())
            }
        }
        .padding([.leading, .trailing], 2)
        .alert("Add Product", isPresented: $showAddProductAlert) {
            TextField("Product ID (e.g., BTC-USD)", text: $newProductId)
            Button("Cancel", role: .cancel) {
                newProductId = ""
            }
            Button("Add") {
                if !newProductId.isEmpty && !productIds.contains(newProductId) {
                    productIds.append(newProductId)
                    selectedProductId = newProductId
                }
                newProductId = ""
            }
        } message: {
            Text("Enter a product ID to add to your order books")
        }
    }
}

