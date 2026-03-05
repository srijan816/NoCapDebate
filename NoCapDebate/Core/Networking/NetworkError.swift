//
//  NetworkError.swift
//  DebateFeedback
//
//

import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case noConnection
    case serverError(statusCode: Int, payload: Data? = nil)
    case decodingError
    case encodingError
    case unauthorized
    case notFound
    case timeout
    case uploadFailed(reason: String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noConnection:
            return Constants.ErrorMessages.networkUnavailable
        case .serverError(let statusCode, let payload):
            if let message = parseServerMessage(from: payload) {
                return message
            }
            return "Server error (Status: \(statusCode))"
        case .decodingError:
            return "Failed to decode server response"
        case .encodingError:
            return "Failed to encode request data"
        case .unauthorized:
            return "Unauthorized. Please log in again."
        case .notFound:
            return "Resource not found"
        case .timeout:
            return "Request timed out. Please try again."
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }

    var isRetriable: Bool {
        switch self {
        case .noConnection, .timeout:
            return true
        case .serverError(let code):
            return code >= 500 // Retry server errors but not client errors
        default:
            return false
        }
    }

    private func parseServerMessage(from payload: Data?) -> String? {
        guard let payload else { return nil }

        if let root = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] {
            if let error = root["error"] as? [String: Any],
               let message = error["message"] as? String,
               !message.isEmpty {
                return message
            }

            if let message = root["message"] as? String,
               !message.isEmpty {
                return message
            }
        }

        return nil
    }
}
