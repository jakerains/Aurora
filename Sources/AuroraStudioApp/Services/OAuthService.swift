import CryptoKit
import Foundation

struct OAuthAuthorizationSession: Sendable {
    let callbackURL: URL
    let codeVerifier: String
    let codeChallengeMethod: String
    let authorizationURL: URL
}

protocol OAuthService: Sendable {
    func beginAuthorization(callbackURL: URL) async throws -> OAuthAuthorizationSession
    func exchangeAuthorizationCode(_ code: String, session: OAuthAuthorizationSession) async throws -> String
}

actor LiveOAuthService: OAuthService {
    private let apiClient: OpenRouterAPIClient

    init(apiClient: OpenRouterAPIClient) {
        self.apiClient = apiClient
    }

    func beginAuthorization(callbackURL: URL) async throws -> OAuthAuthorizationSession {
        let method = "S256"
        let verifier = try randomVerifier(length: 64)
        let challenge = challenge(for: verifier)

        _ = try await apiClient.createAuthCode(
            callbackURL: callbackURL,
            codeChallenge: challenge,
            codeChallengeMethod: method,
            limit: nil
        )

        var components = URLComponents(string: "https://openrouter.ai/auth")
        components?.queryItems = [
            URLQueryItem(name: "callback_url", value: callbackURL.absoluteString),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: method)
        ]

        guard let authorizationURL = components?.url else {
            throw AppError.oauthFailure("Unable to construct authorization URL")
        }

        return OAuthAuthorizationSession(
            callbackURL: callbackURL,
            codeVerifier: verifier,
            codeChallengeMethod: method,
            authorizationURL: authorizationURL
        )
    }

    func exchangeAuthorizationCode(_ code: String, session: OAuthAuthorizationSession) async throws -> String {
        let response = try await apiClient.exchangeAuthCode(
            code: code,
            codeVerifier: session.codeVerifier,
            codeChallengeMethod: session.codeChallengeMethod
        )

        return response.key
    }

    private func randomVerifier(length: Int) throws -> String {
        let charset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        guard status == errSecSuccess else {
            throw AppError.oauthFailure("Unable to generate secure verifier")
        }

        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}
