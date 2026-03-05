import Foundation

protocol APIClientProtocol {
    func setAuthToken(_ token: String?) async

    func request<T: Decodable>(
        endpoint: Endpoint,
        body: Encodable?
    ) async throws -> T

    func upload(
        endpoint: Endpoint,
        fileURL: URL,
        metadata: [String: Any],
        progressHandler: @escaping (Double) -> Void
    ) async throws -> UploadResponse

    func uploadDrillAttempt(
        fileURL: URL,
        metadata: [String: Any],
        progressHandler: @escaping (Double) -> Void
    ) async throws -> DrillAttemptResponse
}

extension APIClientProtocol {
    func request<T: Decodable>(endpoint: Endpoint) async throws -> T {
        try await request(endpoint: endpoint, body: nil)
    }
}
