//
//  Account.swift
//  numeri
//
//  Created by Sharbel Homa on 7/5/25.
//

import Foundation

/// Represents a Coinbase account with balance information (v3 Brokerage API)
struct Account: Identifiable, Codable {
    var id: String { uuid }
    let uuid: String
    let name: String?
    let currency: String
    let availableBalance: Amount
    let `default`: Bool?
    let active: Bool?
    let createdAt: String?
    let updatedAt: String?
    let deletedAt: String?
    let type: String?
    let ready: Bool?
    let hold: Amount?
    let retailPortfolioId: String?
    let platform: String?

    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case currency
        case availableBalance = "available_balance"
        case `default`
        case active
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case type
        case ready
        case hold
        case retailPortfolioId = "retail_portfolio_id"
        case platform
    }
}

/// Amount structure for balance information
struct Amount: Codable {
    let value: String
    let currency: String

    var amountValue: Double? {
        return Double(value)
    }
}

/// Response from Coinbase API v3 when fetching accounts
struct AccountsResponse: Codable {
    let accounts: [Account]
    let hasNext: Bool
    let cursor: String?
    let size: Int?

    enum CodingKeys: String, CodingKey {
        case accounts
        case hasNext = "has_next"
        case cursor
        case size
    }
}
