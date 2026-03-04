import Foundation

// MARK: - Device Code Response

public struct DeviceCodeResponse: Sendable, Decodable {
    public let deviceCode: String
    public let userCode: String
    public let verificationUri: String
    public let verificationUriComplete: String?
    public let expiresIn: Int
    public let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case verificationUriComplete = "verification_uri_complete"
        case expiresIn = "expires_in"
        case interval
    }
}

// MARK: - Access Token Response

public struct AccessTokenResponse: Sendable, Decodable {
    public let accessToken: String
    public let tokenType: String
    public let scope: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
    }
}

// MARK: - Device Flow Error

public enum DeviceFlowError: Error, Sendable {
    case authorizationPending
    case slowDown(newInterval: Int)
    case expiredToken
    case accessDenied
    case deviceFlowDisabled
    case invalidClientId
    case networkError(underlying: Error)
    case unexpectedResponse(String)

    public var isRetryable: Bool {
        switch self {
        case .authorizationPending, .slowDown:
            true
        default:
            false
        }
    }

    public var localizedDescription: String {
        switch self {
        case .authorizationPending:
            "Waiting for authorization..."
        case .slowDown:
            "Polling too fast, slowing down..."
        case .expiredToken:
            "Authorization code expired. Please try again."
        case .accessDenied:
            "Authorization was denied."
        case .deviceFlowDisabled:
            "Device Flow is not enabled for this OAuth App."
        case .invalidClientId:
            "Invalid OAuth client configuration."
        case .networkError(let underlying):
            "Network error: \(underlying.localizedDescription)"
        case .unexpectedResponse(let msg):
            "Unexpected response: \(msg)"
        }
    }
}

// MARK: - Poll Token Result

public enum PollTokenResult: Sendable {
    case token(AccessTokenResponse)
    case pending
    case slowDown(newInterval: Int)
    case failed(DeviceFlowError)
}
