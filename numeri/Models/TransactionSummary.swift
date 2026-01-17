//
//  TransactionSummary.swift
//  numeri
//
//  Created by Sharbel Homa on 7/5/25.
//

import Foundation

/// Response from the transaction summary API
struct TransactionSummaryResponse: Codable {
    let totalVolume: Double?
    let totalFees: Double
    let feeTier: FeeTier
    let marginRate: DecimalValue?
    let goodsAndServicesTax: GoodsAndServicesTax?
    let advancedTradeOnlyVolume: Double?
    let advancedTradeOnlyFees: Double?
    let coinbaseProVolume: Double?
    let coinbaseProFees: Double?
    let totalBalance: String?
    let volumeBreakdown: [Volume]?
    let hasCostPlusCommission: Bool?

    enum CodingKeys: String, CodingKey {
        case totalVolume = "total_volume"
        case totalFees = "total_fees"
        case feeTier = "fee_tier"
        case marginRate = "margin_rate"
        case goodsAndServicesTax = "goods_and_services_tax"
        case advancedTradeOnlyVolume = "advanced_trade_only_volume"
        case advancedTradeOnlyFees = "advanced_trade_only_fees"
        case coinbaseProVolume = "coinbase_pro_volume"
        case coinbaseProFees = "coinbase_pro_fees"
        case totalBalance = "total_balance"
        case volumeBreakdown = "volume_breakdown"
        case hasCostPlusCommission = "has_cost_plus_commission"
    }
}

/// Fee tier information
struct FeeTier: Codable {
    let pricingTier: String
    let takerFeeRate: String
    let makerFeeRate: String
    let aopFrom: String
    let aopTo: String
    let volumeTypesAndRange: [VolumeTypesAndRange]?

    enum CodingKeys: String, CodingKey {
        case pricingTier = "pricing_tier"
        case takerFeeRate = "taker_fee_rate"
        case makerFeeRate = "maker_fee_rate"
        case aopFrom = "aop_from"
        case aopTo = "aop_to"
        case volumeTypesAndRange = "volume_types_and_range"
    }
    
    /// Get maker fee rate as a Double
    var makerFeeRateDouble: Double {
        Double(makerFeeRate) ?? 0.0
    }
    
    /// Get taker fee rate as a Double
    var takerFeeRateDouble: Double {
        Double(takerFeeRate) ?? 0.0
    }
}

/// Volume types and range for fee tier calculation
struct VolumeTypesAndRange: Codable {
    let volumeTypes: [VolumeType]
    let volFrom: String
    let volTo: String

    enum CodingKeys: String, CodingKey {
        case volumeTypes = "volume_types"
        case volFrom = "vol_from"
        case volTo = "vol_to"
    }
}

/// Volume type enum
enum VolumeType: String, Codable {
    case unknown = "VOLUME_TYPE_UNKNOWN"
    case spot = "VOLUME_TYPE_SPOT"
    case intxPerps = "VOLUME_TYPE_INTX_PERPS"
    case usDerivatives = "VOLUME_TYPE_US_DERIVATIVES"
}

/// Volume breakdown
struct Volume: Codable {
    let volumeType: VolumeType
    let volume: Double

    enum CodingKeys: String, CodingKey {
        case volumeType = "volume_type"
        case volume
    }
}

/// Decimal value representation
struct DecimalValue: Codable {
    let value: String
    
    var doubleValue: Double {
        Double(value) ?? 0.0
    }
}

/// Goods and Services Tax information
struct GoodsAndServicesTax: Codable {
    let rate: String
    let type: GstType
    
    var rateDouble: Double {
        Double(rate) ?? 0.0
    }
}

/// GST Type enum
enum GstType: String, Codable {
    case inclusive = "INCLUSIVE"
    case exclusive = "EXCLUSIVE"
}
