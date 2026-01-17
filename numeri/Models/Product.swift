//
//  Product.swift
//  numeri
//
//  Created by Sharbel Homa on 7/5/25.
//

import Foundation

/// Represents a Coinbase trading product (currency pair)
struct Product: Identifiable, Codable {
    let id: String // product_id
    let productId: String
    let price: String?
    let pricePercentageChange24h: String?
    let volume24h: String?
    let volumePercentageChange24h: String?
    let baseName: String
    let quoteName: String
    let baseDisplaySymbol: String
    let quoteDisplaySymbol: String
    let status: String
    let isDisabled: Bool
    let tradingDisabled: Bool
    let productType: ProductType?

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case price
        case pricePercentageChange24h = "price_percentage_change_24h"
        case volume24h = "volume_24h"
        case volumePercentageChange24h = "volume_percentage_change_24h"
        case baseName = "base_name"
        case quoteName = "quote_name"
        case baseDisplaySymbol = "base_display_symbol"
        case quoteDisplaySymbol = "quote_display_symbol"
        case status
        case isDisabled = "is_disabled"
        case tradingDisabled = "trading_disabled"
        case productType = "product_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        productId = try container.decode(String.self, forKey: .productId)
        id = productId // Use productId as the id for Identifiable
        price = try container.decodeIfPresent(String.self, forKey: .price)
        pricePercentageChange24h = try container.decodeIfPresent(String.self, forKey: .pricePercentageChange24h)
        volume24h = try container.decodeIfPresent(String.self, forKey: .volume24h)
        volumePercentageChange24h = try container.decodeIfPresent(String.self, forKey: .volumePercentageChange24h)
        baseName = try container.decode(String.self, forKey: .baseName)
        quoteName = try container.decode(String.self, forKey: .quoteName)
        baseDisplaySymbol = try container.decode(String.self, forKey: .baseDisplaySymbol)
        quoteDisplaySymbol = try container.decode(String.self, forKey: .quoteDisplaySymbol)
        status = try container.decode(String.self, forKey: .status)
        isDisabled = try container.decode(Bool.self, forKey: .isDisabled)
        tradingDisabled = try container.decode(Bool.self, forKey: .tradingDisabled)
        productType = try container.decodeIfPresent(ProductType.self, forKey: .productType)
    }

    var displayName: String {
        "\(baseDisplaySymbol)-\(quoteDisplaySymbol)"
    }

    var isTradable: Bool {
        !isDisabled && !tradingDisabled && status.lowercased() == "online"
    }
}

enum ProductType: String, Codable {
    case unknown = "UNKNOWN_PRODUCT_TYPE"
    case spot = "SPOT"
    case future = "FUTURE"
}

/// Response from Coinbase API when fetching products
struct ProductsResponse: Codable {
    let products: [Product]
    let numProducts: Int?
    let pagination: PaginationMetadata?

    enum CodingKeys: String, CodingKey {
        case products
        case numProducts = "num_products"
        case pagination
    }
}

struct PaginationMetadata: Codable {
    let prevCursor: String?
    let nextCursor: String?
    let hasNext: Bool?
    let hasPrev: Bool?

    enum CodingKeys: String, CodingKey {
        case prevCursor = "prev_cursor"
        case nextCursor = "next_cursor"
        case hasNext = "has_next"
        case hasPrev = "has_prev"
    }
}
