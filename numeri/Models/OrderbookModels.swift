//
//  OrderbookModels.swift
//  numeri
//
//  Created by Sharbel Homa on 7/4/25.
//

import Foundation

struct GenericMessage: Codable {
    let type: String?
    let message: String?
    let reason: String?
}

struct OrderbookMessage: Codable {
    let channel: String?
    let clientId: String?
    let timestamp: String?
    let sequenceNum: Int?
    let events: [OrderbookEvent]?
    let type: String?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case channel, timestamp, type, message
        case clientId = "client_id"
        case sequenceNum = "sequence_num"
        case events
    }
}

struct OrderbookEvent: Codable {
    let type: String?
    let productId: String?
    let updates: [OrderbookUpdate]?
    let subscriptions: SubscriptionInfo?
    
    enum CodingKeys: String, CodingKey {
        case type
        case productId = "product_id"
        case updates
        case subscriptions
    }
}

struct SubscriptionInfo: Codable {
    let level2: [String]?
}

struct OrderbookUpdate: Codable {
    let side: String
    let eventTime: String
    let priceLevel: String
    let newQuantity: String
    
    enum CodingKeys: String, CodingKey {
        case side
        case eventTime = "event_time"
        case priceLevel = "price_level"
        case newQuantity = "new_quantity"
    }
}

struct OrderbookEntry: Identifiable, Equatable, Comparable {
    let id = UUID()
    let price: Double
    let quantity: Double
    let side: String
    let timestamp: String
    
    nonisolated static func < (lhs: OrderbookEntry, rhs: OrderbookEntry) -> Bool {
        if lhs.price != rhs.price {
            return lhs.price < rhs.price
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
    
    nonisolated static func == (lhs: OrderbookEntry, rhs: OrderbookEntry) -> Bool {
        return lhs.id == rhs.id
    }
}

enum OrderBookType {
    case bid, offer
}

// Atomic snapshot of orderbook state to ensure bids and offers are from the same point in time
struct OrderbookSnapshot {
    let bids: [OrderbookEntry]
    let offers: [OrderbookEntry]
    let timestamp: Date
    let latencyMs: Int
    
    var midPrice: Double? {
        guard let bestBid = bids.first, let bestAsk = offers.first else {
            if let bestBid = bids.first {
                return bestBid.price
            }
            if let bestAsk = offers.first {
                return bestAsk.price
            }
            return nil
        }
        return (bestBid.price + bestAsk.price) / 2
    }
}

