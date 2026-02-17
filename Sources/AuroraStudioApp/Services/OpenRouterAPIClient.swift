import Foundation

struct OAuthAuthCodeResponse: Decodable {
    struct DataObject: Decodable {
        let id: String
        let appID: Int?
        let createdAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case appID = "app_id"
            case createdAt = "created_at"
        }
    }

    let data: DataObject
}

struct OAuthExchangeResponse: Decodable {
    let key: String
    let userID: String?

    enum CodingKeys: String, CodingKey {
        case key
        case userID = "user_id"
    }
}

protocol OpenRouterAPIClient: Sendable {
    func fetchModels() async throws -> [OpenRouterModel]
    func fetchUserModels() async throws -> [OpenRouterModel]
    func createChatCompletion(_ request: ChatCompletionsRequest) async throws -> ChatCompletionsResponse
    func createAuthCode(
        callbackURL: URL,
        codeChallenge: String,
        codeChallengeMethod: String,
        limit: Double?
    ) async throws -> OAuthAuthCodeResponse
    func exchangeAuthCode(
        code: String,
        codeVerifier: String,
        codeChallengeMethod: String
    ) async throws -> OAuthExchangeResponse
}

final class LiveOpenRouterAPIClient: OpenRouterAPIClient {
    private let baseURL = URL(string: "https://openrouter.ai/api/v1/")
    private let session: URLSession
    private let apiKeyProvider: @Sendable () throws -> String

    init(
        session: URLSession = .shared,
        apiKeyProvider: @escaping @Sendable () throws -> String
    ) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
    }

    func fetchModels() async throws -> [OpenRouterModel] {
        let request = try authorizedRequest(path: "models", method: "GET")
        let response: OpenRouterModelsResponse = try await send(request: request)
        return response.data
    }

    func fetchUserModels() async throws -> [OpenRouterModel] {
        let request = try authorizedRequest(path: "models/user", method: "GET")
        let response: OpenRouterModelsResponse = try await send(request: request)
        return response.data
    }

    func createChatCompletion(_ requestBody: ChatCompletionsRequest) async throws -> ChatCompletionsResponse {
        var request = try authorizedRequest(path: "chat/completions", method: "POST")
        request.httpBody = try encodeBody(requestBody)
        return try await send(request: request)
    }

    func createAuthCode(
        callbackURL: URL,
        codeChallenge: String,
        codeChallengeMethod: String,
        limit: Double? = nil
    ) async throws -> OAuthAuthCodeResponse {
        struct Body: Encodable {
            let callbackURL: String
            let codeChallenge: String
            let codeChallengeMethod: String
            let limit: Double?

            enum CodingKeys: String, CodingKey {
                case callbackURL = "callback_url"
                case codeChallenge = "code_challenge"
                case codeChallengeMethod = "code_challenge_method"
                case limit
            }
        }

        var request = try authorizedRequest(path: "auth/keys/code", method: "POST")
        request.httpBody = try encodeBody(
            Body(
                callbackURL: callbackURL.absoluteString,
                codeChallenge: codeChallenge,
                codeChallengeMethod: codeChallengeMethod,
                limit: limit
            )
        )

        return try await send(request: request)
    }

    func exchangeAuthCode(
        code: String,
        codeVerifier: String,
        codeChallengeMethod: String
    ) async throws -> OAuthExchangeResponse {
        struct Body: Encodable {
            let code: String
            let codeVerifier: String
            let codeChallengeMethod: String

            enum CodingKeys: String, CodingKey {
                case code
                case codeVerifier = "code_verifier"
                case codeChallengeMethod = "code_challenge_method"
            }
        }

        var request = try authorizedRequest(path: "auth/keys", method: "POST")
        request.httpBody = try encodeBody(
            Body(
                code: code,
                codeVerifier: codeVerifier,
                codeChallengeMethod: codeChallengeMethod
            )
        )

        return try await send(request: request)
    }

    private func authorizedRequest(path: String, method: String) throws -> URLRequest {
        guard let baseURL, let url = URL(string: path, relativeTo: baseURL) else {
            throw AppError.invalidURL
        }

        let apiKey = try apiKeyProvider()

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60
        return request
    }

    private func encodeBody<T: Encodable>(_ body: T) throws -> Data {
        do {
            return try JSONEncoder().encode(body)
        } catch {
            throw AppError.encodingFailure(error.localizedDescription)
        }
    }

    private func send<T: Decodable>(request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw AppError.httpStatus(http.statusCode, body)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AppError.decodingFailure(error.localizedDescription)
        }
    }
}
