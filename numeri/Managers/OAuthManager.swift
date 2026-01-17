//
//  OAuthManager.swift
//  numeri
//
//  Created by Sharbel Homa on 7/5/25.
//

import AuthenticationServices
import Combine
import CryptoKit
import Foundation

class OAuthManager: ObservableObject {
    @Published var accessToken: String?
    @Published var refreshToken: String?
    @Published var accounts: [Account] = []
    @Published var isLoadingAccounts: Bool = false
    @Published var accountsError: String?
    @Published var oauthError: String?
    private let clientId = "74c1200b-14ea-494c-ba14-739e460d20d4"
    private let clientSecret = "NL736EGv3woKJLYX39~v-FcnsX"
    private let redirectUri = "numeri://auth/callback"
    private let authUrl = "https://api.coinbase.com/oauth/authorize"
    private let tokenUrl = "https://api.coinbase.com/oauth/token"
    private let apiBaseUrl = "https://api.coinbase.com"
    let keychainService = "com.numeri"
    private var isRefreshingToken = false
    private let refreshQueue = DispatchQueue(label: "com.numeri.token.refresh", qos: .userInitiated)

    func startOAuthFlow(presentationAnchor: ASWebAuthenticationPresentationContextProviding) {
        let authUrlString = "\(authUrl)?response_type=code&client_id=\(clientId)&redirect_uri=\(redirectUri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectUri)&scope=wallet:accounts:read wallet:trades:read wallet:trades:create wallet:buys:read wallet:buys:create wallet:sells:read wallet:sells:create wallet:transactions:read offline_access"
        guard let authUrl = URL(string: authUrlString) else {
            return
        }

        let session = ASWebAuthenticationSession(url: authUrl, callbackURLScheme: "numeri") { [weak self] callbackUrl, error in
            DispatchQueue.main.async {
                if let error = error {
                    // Check if it's a user cancellation (not a real error)
                    if let authError = error as? ASWebAuthenticationSessionError,
                       authError.code == .canceledLogin
                    {
                        self?.oauthError = nil // User canceled, not an error
                        return
                    }
                    self?.oauthError = "OAuth error: \(error.localizedDescription)"
                    print("OAuth session error: \(error)")
                    return
                }

                guard let url = callbackUrl,
                      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    self?.oauthError = "Failed to receive authorization code from callback"
                    print("OAuth callback error: Invalid callback URL or missing code")
                    return
                }

                self?.oauthError = nil // Clear any previous errors
                self?.exchangeCodeForTokens(code: code)
            }
        }

        session.prefersEphemeralWebBrowserSession = true
        session.presentationContextProvider = presentationAnchor
        guard session.start() else {
            return
        }
    }

    private func exchangeCodeForTokens(code: String) {
        guard let url = URL(string: tokenUrl) else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body = "grant_type=authorization_code&code=\(code)&client_id=\(clientId)&client_secret=\(clientSecret)&redirect_uri=\(redirectUri)"
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.oauthError = "Token exchange error: \(error.localizedDescription)"
                    print("Token exchange error: \(error)")
                    return
                }

                guard let data = data else {
                    self?.oauthError = "Token exchange error: No data received"
                    print("Token exchange error: No data")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode != 200
                {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    self?.oauthError = "Token exchange failed (status \(httpResponse.statusCode)): \(errorMessage)"
                    print("Token exchange failed: \(errorMessage)")
                    return
                }

                do {
                    let decoder = JSONDecoder()
                    let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
                    self?.saveTokens(accessToken: tokenResponse.accessToken, refreshToken: tokenResponse.refreshToken)
                    self?.accessToken = tokenResponse.accessToken
                    self?.refreshToken = tokenResponse.refreshToken
                    self?.oauthError = nil // Clear any previous errors
                    print("Successfully obtained tokens")
                } catch {
                    self?.oauthError = "Failed to decode token response: \(error.localizedDescription)"
                    print("Token decode error: \(error)")
                }
            }
        }.resume()
    }

    private func saveTokens(accessToken: String, refreshToken: String) {
        let accessQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "coinbase_access_token",
            kSecValueData as String: accessToken.data(using: .utf8)!,
        ]
        let refreshQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "coinbase_refresh_token",
            kSecValueData as String: refreshToken.data(using: .utf8)!,
        ]

        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService] as CFDictionary)
        SecItemAdd(accessQuery as CFDictionary, nil)
        SecItemAdd(refreshQuery as CFDictionary, nil)
    }

    func loadTokens() {
        let accessQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "coinbase_access_token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var accessItem: CFTypeRef?
        if SecItemCopyMatching(accessQuery as CFDictionary, &accessItem) == errSecSuccess,
           let accessData = accessItem as? Data,
           let accessToken = String(data: accessData, encoding: .utf8)
        {
            self.accessToken = accessToken
        }

        let refreshQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "coinbase_refresh_token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var refreshItem: CFTypeRef?
        if SecItemCopyMatching(refreshQuery as CFDictionary, &refreshItem) == errSecSuccess,
           let refreshData = refreshItem as? Data,
           let refreshToken = String(data: refreshData, encoding: .utf8)
        {
            self.refreshToken = refreshToken
        }
    }

    @MainActor
    func logout() async {
        let tokenToRevoke = refreshToken

        if let token = tokenToRevoke {
            await revokeToken(token)
        }

        accessToken = nil
        refreshToken = nil
        accounts = []
        accountsError = nil
        isLoadingAccounts = false

        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService] as CFDictionary)
    }

    private func revokeToken(_ token: String) async {
        guard let url = URL(string: "https://api.coinbase.com/oauth/revoke") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "token=\(token)&client_id=\(clientId)&client_secret=\(clientSecret)"
        request.httpBody = body.data(using: .utf8)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {}
            }
        } catch {}
    }

    /// Refresh the access token using the refresh token
    @MainActor
    func refreshAccessToken() async -> Bool {
        guard let refreshToken = refreshToken else {
            print("No refresh token available")
            return false
        }

        // Prevent multiple simultaneous refresh attempts
        if isRefreshingToken {
            // Wait for the current refresh to complete
            while isRefreshingToken {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            return accessToken != nil
        }

        isRefreshingToken = true
        defer { isRefreshingToken = false }

        guard let url = URL(string: tokenUrl) else {
            print("Invalid token URL")
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=\(clientId)&client_secret=\(clientSecret)"
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response when refreshing token")
                return false
            }

            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("Token refresh failed (status \(httpResponse.statusCode)): \(errorMessage)")
                // If refresh token is invalid, clear tokens
                if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                    accessToken = nil
                    self.refreshToken = nil
                    SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService] as CFDictionary)
                }
                return false
            }

            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
            // Use new refresh token if provided and non-empty, otherwise keep the existing one
            let newRefreshToken = (tokenResponse.refreshToken.isEmpty) ? refreshToken : tokenResponse.refreshToken
            saveTokens(accessToken: tokenResponse.accessToken, refreshToken: newRefreshToken)
            accessToken = tokenResponse.accessToken
            self.refreshToken = newRefreshToken
            print("Successfully refreshed access token")
            return true
        } catch {
            print("Token refresh error: \(error.localizedDescription)")
            return false
        }
    }

    /// Fetch user accounts and balances from Coinbase API
    func fetchAccounts() async {
        await fetchAccountsWithRetry(shouldRetry: true)
    }

    private func fetchAccountsWithRetry(shouldRetry: Bool) async {
        guard let accessToken = accessToken else {
            DispatchQueue.main.async {
                self.accountsError = "No access token available"
            }
            return
        }

        DispatchQueue.main.async {
            self.isLoadingAccounts = true
            self.accountsError = nil
        }

        guard let url = URL(string: "\(apiBaseUrl)/api/v3/brokerage/accounts") else {
            DispatchQueue.main.async {
                self.isLoadingAccounts = false
                self.accountsError = "Invalid API URL"
            }
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.isLoadingAccounts = false
                    self.accountsError = "Invalid response"
                }
                return
            }

            // If we get 401 or 403, try refreshing the token and retry once
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403, shouldRetry {
                print("Access token expired (status \(httpResponse.statusCode)), attempting to refresh...")
                let refreshSuccess = await refreshAccessToken()

                if refreshSuccess {
                    print("Token refreshed successfully, retrying accounts fetch...")
                    // Retry the request with the new token
                    await fetchAccountsWithRetry(shouldRetry: false)
                    return
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    DispatchQueue.main.async {
                        self.isLoadingAccounts = false
                        self.accountsError = "Failed to refresh token. Please log in again."
                    }
                    return
                }
            }

            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                DispatchQueue.main.async {
                    self.isLoadingAccounts = false
                    self.accountsError = "Failed to fetch accounts: \(errorMessage)"
                }
                return
            }

            let decoder = JSONDecoder()
            let accountsResponse = try decoder.decode(AccountsResponse.self, from: data)

            DispatchQueue.main.async {
                self.accounts = accountsResponse.accounts
                self.isLoadingAccounts = false
                self.accountsError = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoadingAccounts = false
                self.accountsError = "Error fetching accounts: \(error.localizedDescription)"
            }
        }
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}
