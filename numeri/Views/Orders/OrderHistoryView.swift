//
//  OrderHistoryView.swift
//  numeri
//
//  Created by Sharbel Homa on 7/5/25.
//

import SwiftUI

struct OrderHistoryView: View {
    @ObservedObject var orderManager: OrderExecutionManager
    @State private var selectedStatus: OrderStatus? = nil
    @State private var selectedProductId: String? = nil
    @State private var showFilters = false
    
    private var filteredOrders: [Order] {
        var orders = orderManager.recentOrders
        
        if let status = selectedStatus {
            orders = orders.filter { $0.status == status }
        }
        
        if let productId = selectedProductId {
            orders = orders.filter { $0.productId == productId }
        }
        
        return orders.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with filters
            VStack(spacing: 8) {
                HStack {
                    Text("Order History")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: { showFilters.toggle() }) {
                        Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
                
                if showFilters {
                    HStack(spacing: 12) {
                        // Status filter
                        Picker("Status", selection: $selectedStatus) {
                            Text("All").tag(OrderStatus?.none)
                            Text("Pending").tag(OrderStatus?.some(.pending))
                            Text("Open").tag(OrderStatus?.some(.open))
                            Text("Filled").tag(OrderStatus?.some(.filled))
                            Text("Canceled").tag(OrderStatus?.some(.canceled))
                        }
                        .pickerStyle(.menu)
                        
                        Spacer()
                        
                        Text("\(filteredOrders.count) orders")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Orders list
            if filteredOrders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No orders found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredOrders) { order in
                            OrderCard(order: order, orderManager: orderManager)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

