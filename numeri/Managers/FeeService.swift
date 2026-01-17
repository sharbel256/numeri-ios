//
//  FeeService.swift
//  numeri
//
//  Created by Sharbel Homa on 7/5/25.
//

import Combine
import Foundation

/// Service for fetching fee information from Coinbase API
class FeeService: ObservableObject {
    @Published var transactionSummary: TransactionSummaryResponse?
    @Published var isLoading = false
    @Published var error: String?

    private let baseURL = "https://api.coinbase.com/api/v3/brokerage/transaction_summary"
    private var accessToken: String?
    private var tokenRefreshHandler: (() async -> String?)?
    private var hasFetched = false

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

    /// Fetches transaction summary from Coinbase API (one-time call)
    /// - Parameters:
    ///   - productType: Filter by product type (default: SPOT)
    ///   - contractExpiryType: Filter by contract expiry type (only for FUTURE)
    ///   - productVenue: Filter by product venue
    func fetchTransactionSummary(
        productType: String? = nil,
        contractExpiryType: String? = nil,
        productVenue: String? = nil
    ) async {
        // Only fetch once
        guard !hasFetched else {
            return
        }
        
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
        var queryItems: [URLQueryItem] = []

        if let productType = productType {
            queryItems.append(URLQueryItem(name: "product_type", value: productType))
        }
        if let contractExpiryType = contractExpiryType {
            queryItems.append(URLQueryItem(name: "contract_expiry_type", value: contractExpiryType))
        }
        if let productVenue = productVenue {
            queryItems.append(URLQueryItem(name: "product_venue", value: productVenue))
        }

        if !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems
        }

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
                throw FeeServiceError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                if let errorData = try? JSONDecoder().decode(FeeErrorResponse.self, from: data) {
                    let errorMessage = errorData.message ?? errorData.error ?? "Unknown error"
                    throw FeeServiceError.apiError(errorMessage)
                }
                throw FeeServiceError.httpError(httpResponse.statusCode)
            }

            let response = try JSONDecoder().decode(TransactionSummaryResponse.self, from: data)

            await MainActor.run {
                transactionSummary = response
                isLoading = false
                hasFetched = true
            }
        } catch {
            await MainActor.run {
                if let serviceError = error as? FeeServiceError {
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
            throw FeeServiceError.apiError("Authentication required. Please log in.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeeServiceError.invalidResponse
        }

        // If we get 401 or 403, try refreshing the token and retry once
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403, shouldRetry {
            print("Access token expired (status \(httpResponse.statusCode)), attempting to refresh...")
            let refreshSuccess = await refreshTokenIfNeeded()

            if refreshSuccess {
                print("Token refreshed successfully, retrying API request...")
                return try await makeAPIRequest(url: url, shouldRetry: false)
            } else {
                throw FeeServiceError.apiError("Failed to refresh token. Please log in again.")
            }
        }

        return (data, response)
    }
    
    /// Reset the fetch flag (useful for testing or re-fetching after login)
    func reset() {
        hasFetched = false
    }
}

enum FeeServiceError: Error {
    case apiError(String)
    case httpError(Int)
    case invalidResponse
    case invalidURL
}

struct FeeErrorResponse: Codable {
    let error: String?
    let message: String?
}
