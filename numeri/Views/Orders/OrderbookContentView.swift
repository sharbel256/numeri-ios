//
//  OrderbookContentView.swift
//  numeri
//
//  Created by Sharbel Homa on 6/29/25.
//

import SwiftUI

struct OrderbookContentView: View {
    @ObservedObject var webSocketManager: WebSocketManager
    let maxQuantity: Double
    let productId: String
    
    private var baseCurrency: String {
        let components = productId.split(separator: "-")
        return components.first.map(String.init) ?? "BTC"
    }
    
    private var quoteCurrency: String {
        let components = productId.split(separator: "-")
        return components.count > 1 ? String(components[1]) : "USD"
    }
    
    private var allBids: [OrderbookEntry] {
        webSocketManager.bids.getElements()
    }
    
    private var allOffers: [OrderbookEntry] {
        webSocketManager.offers.getElements()
    }
    
    private var bestBid: OrderbookEntry? {
        allBids.first
    }
    
    private var bestAsk: OrderbookEntry? {
        allOffers.first
    }
    
    // Always return 11 entries, using placeholder entries with 0 values when data is not available
    private var offers: [OrderbookEntry] {
        let availableOffers = Array(allOffers.prefix(11))
        let neededCount = 11 - availableOffers.count
        
        if neededCount > 0 {
            let placeholders = (0..<neededCount).map { _ in
                OrderbookEntry(
                    price: 0.0,
                    quantity: 0.0,
                    side: "offer",
                    timestamp: ""
                )
            }
            return availableOffers + placeholders
        }
        
        return availableOffers
    }
    
    private var bids: [OrderbookEntry] {
        let availableBids = Array(allBids.prefix(11))
        let neededCount = 11 - availableBids.count
        
        if neededCount > 0 {
            let placeholders = (0..<neededCount).map { _ in
                OrderbookEntry(
                    price: 0.0,
                    quantity: 0.0,
                    side: "bid",
                    timestamp: ""
                )
            }
            return availableBids + placeholders
        }
        
        return availableBids
    }
    
    private var midPrice: Double {
        if let bestBidPrice = bestBid?.price, let bestAskPrice = bestAsk?.price {
            return (bestBidPrice + bestAskPrice) / 2
        }
        if let highestBid = bestBid?.price {
            return highestBid
        }
        if let lowestOffer = bestAsk?.price {
            return lowestOffer
        }
        return 0
    }
    
    private var spread: Double? {
        guard let bestBidPrice = bestBid?.price,
              let bestAskPrice = bestAsk?.price else {
            return nil
        }
        return bestAskPrice - bestBidPrice
    }
    
    private var spreadPercentage: Double? {
        guard let spread = spread, midPrice > 0 else { return nil }
        return (spread / midPrice) * 100
    }
    
    private var headerView: some View {
        HStack {
            Text("Price (\(quoteCurrency))")
                .frame(width: 70, alignment: .leading)
            Spacer()
            Text("Amount (\(baseCurrency))")
                .frame(width: 100, alignment: .trailing)
        }
        .font(.caption)
        .foregroundColor(.gray)
        .padding(.vertical, 4)
    }
    
    var body: some View {
        VStack {
            VStack(spacing: 5) {
                VStack(spacing: 0) {
                    headerView
                    ForEach(offers) { offer in
                        OrderbookRow(entry: offer, type: .offer, maxQuantity: maxQuantity)
                    }
                }
                
                VStack(spacing: 2) {
                    Text("$\(midPrice, specifier: "%.2f")")
                        .font(.system(size: 14))
                    if let spread = spread {
                        Text("Spread: $\(spread, specifier: "%.2f")")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        if let spreadPct = spreadPercentage {
                            Text("(\(spreadPct, specifier: "%.3f")%)")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 0) {
                    ForEach(bids) { bid in
                        OrderbookRow(entry: bid, type: .bid, maxQuantity: maxQuantity)
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: 150)
    }
}

