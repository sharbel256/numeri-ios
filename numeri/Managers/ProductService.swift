//
//  ProductService.swift
//  numeri
//
//  Created by Sharbel Homa on 7/5/25.
//

import Combine
import Foundation

/// Service for fetching products from Coinbase API
class ProductService: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var error: String?

    private let baseURL = "https://api.coinbase.com/api/v3/brokerage/products"
    private var accessToken: String?
    private var tokenRefreshHandler: (() async -> String?)?

    init(accessToken: String?, tokenRefreshHandler: (() async -> String?)? = nil) {
        self.accessToken = accessToken
        self.tokenRefreshHandler = tokenRefreshHandler
    }

    func updateToken(_ newToken: String?) {
        accessToken = newToken
    }

    func setTokenRefreshHandler(_ handler: @escaping () async -> String?) {
        tokenRefreshHandler = handler
    }

    /// Fetches products from Coinbase API
    /// - Parameters:
    ///   - productType: Filter by product type (default: SPOT)
    ///   - limit: Number of products to return (default: 250)
    ///   - searchQuery: Optional search query to filter products
    func fetchProducts(
        productType: ProductType = .spot,
        limit: Int = 250,
        searchQuery: String? = nil
    ) async {
        guard accessToken != nil else {
            await MainActor.run {
                self.error = "Authentication required. Please log in."
                isLoading = false
            }
            return
        }

        await MainActor.run {
            isLoading = true
            self.error = nil
        }

        var urlComponents = URLComponents(string: baseURL)
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "product_type", value: productType.rawValue),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            await MainActor.run {
                self.error = "Invalid URL"
                isLoading = false
            }
            return
        }

        do {
            let (data, httpResponse) = try await makeAPIRequest(url: url)

            guard let httpResponse = httpResponse as? HTTPURLResponse else {
                throw ProductServiceError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                if let errorData = try? JSONDecoder().decode(ProductErrorResponse.self, from: data) {
                    let errorMessage = errorData.message ?? errorData.error ?? "Unknown error"
                    throw ProductServiceError.apiError(errorMessage)
                }
                throw ProductServiceError.httpError(httpResponse.statusCode)
            }

            let response = try JSONDecoder().decode(ProductsResponse.self, from: data)

            var filteredProducts = response.products

            // Filter by search query if provided
            if let query = searchQuery?.lowercased(), !query.isEmpty {
                filteredProducts = filteredProducts.filter { product in
                    product.productId.lowercased().contains(query) ||
                        product.baseDisplaySymbol.lowercased().contains(query) ||
                        product.quoteDisplaySymbol.lowercased().contains(query) ||
                        product.baseName.lowercased().contains(query) ||
                        product.quoteName.lowercased().contains(query)
                }
            }

            // Sort by volume (highest first) if available, otherwise by product ID
            filteredProducts.sort { product1, product2 in
                if let vol1 = product1.volume24h, let vol2 = product2.volume24h,
                   let vol1Double = Double(vol1), let vol2Double = Double(vol2)
                {
                    return vol1Double > vol2Double
                }
                return product1.productId < product2.productId
            }

            await MainActor.run {
                products = filteredProducts
                isLoading = false
            }
        } catch {
            await MainActor.run {
                if let serviceError = error as? ProductServiceError {
                    switch serviceError {
                    case let .apiError(message):
                        self.error = message
                    case let .httpError(code):
                        self.error = "HTTP error: \(code)"
                    case .invalidResponse:
                        self.error = "Invalid response from server"
                    case .invalidURL:
                        self.error = "Invalid URL"
                    }
                } else {
                    self.error = error.localizedDescription
                }
                isLoading = false
            }
        }
    }

    private func refreshTokenIfNeeded() async -> Bool {
        guard let handler = tokenRefreshHandler else {
            return false
        }

        if let newToken = await handler() {
            accessToken = newToken
            return true
        }
        return false
    }

    private func makeAPIRequest(
        url: URL,
        shouldRetry: Bool = true
    ) async throws -> (Data, URLResponse) {
        guard let token = accessToken else {
            throw ProductServiceError.apiError("Authentication required. Please log in.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProductServiceError.invalidResponse
        }

        // If we get 401 or 403, check if it's a scope error
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            // Try to parse the error response to see if it's a scope issue
            if let errorData = try? JSONDecoder().decode(ProductErrorResponse.self, from: data) {
                let errorMessage = errorData.message ?? errorData.error ?? "Unknown error"
                let errorLower = errorMessage.lowercased()
                
                // If it's a scope/permission error, don't try to refresh (refresh won't fix scope issues)
                if errorLower.contains("scope") || errorLower.contains("missing required") || errorLower.contains("permission") {
                    throw ProductServiceError.apiError(errorMessage)
                }
            }
            
            // If it's not a scope error and we should retry, try refreshing the token
            if shouldRetry {
                print("Access token expired (status \(httpResponse.statusCode)), attempting to refresh...")
                let refreshSuccess = await refreshTokenIfNeeded()

                if refreshSuccess {
                    print("Token refreshed successfully, retrying API request...")
                    return try await makeAPIRequest(url: url, shouldRetry: false)
                } else {
                    throw ProductServiceError.apiError("Failed to refresh token. Please log in again.")
                }
            }
        }

        return (data, response)
    }
}

enum ProductServiceError: Error {
    case apiError(String)
    case httpError(Int)
    case invalidResponse
    case invalidURL
}

struct ProductErrorResponse: Codable {
    let error: String?
    let message: String?
}
