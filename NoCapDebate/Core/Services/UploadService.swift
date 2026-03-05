//
//  UploadService.swift
//  DebateFeedback
//
//
//

import Foundation
import SwiftData
import AVFoundation

protocol UploadServicing {
    func uploadSpeech(
        recording: SpeechRecording,
        debateSession: DebateSession,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> String
    func cancelUpload(for recordingId: UUID)
    func isUploading(recordingId: UUID) -> Bool
}

protocol DataControllerProviding {
    func backgroundContext() -> ModelContext
}

extension DataController: DataControllerProviding {}

@Observable
final class UploadService: NSObject {
    static let shared = UploadService()

    private var activeUploads: [UUID: UploadTask] = [:]
    private let apiClient: APIClientProtocol
    private let dataController: DataControllerProviding
    
    // Create a dedicated background dispatcher for upload logic
    private let queue = DispatchQueue(label: "com.debatefeedback.uploadService")

    init(
        apiClient: APIClientProtocol = APIClient.shared,
        dataController: DataControllerProviding = DataController.shared
    ) {
        self.apiClient = apiClient
        self.dataController = dataController
        super.init()
        Task {
            await resumePendingUploads()
        }
    }

    // MARK: - Upload Methods

    func uploadSpeech(
        recording: SpeechRecording,
        debateSession: DebateSession,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> String {
        let uploadId = recording.id
        let debateId = debateSession.backendDebateId ?? debateSession.id.uuidString
        let fileURL = URL(fileURLWithPath: recording.localFilePath)

        // Calculate file size
        let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? UInt64
        let fileSizeMB = Double(fileSize ?? 0) / (1024 * 1024)
        let uploadStartTime = Date()

        // Track upload started
        AnalyticsService.shared.logUploadStarted(
            speechId: nil,
            fileSizeMB: fileSizeMB,
            networkType: "unknown" // TODO: Add network type detection
        )

        // 1. Prepare metadata
        let resolvedDuration = await ensureDuration(for: recording, fileURL: fileURL)
        let metadata: [String: Any] = [
            "debate_id": debateId,
            "speaker_name": recording.speakerName,
            "speaker_position": recording.speakerPosition,
            "duration_seconds": resolvedDuration,
            "student_level": debateSession.studentLevel.rawValue
        ]

        // 2. Persist UploadRequest
        let context = dataController.backgroundContext()
        let request = UploadRequest(
            id: uploadId,
            fileURL: fileURL,
            metadata: metadata,
            status: .pending
        )
        context.insert(request)
        try? context.save()

        // 3. Track in-memory
        let task = UploadTask(id: uploadId, fileURL: fileURL)
        activeUploads[uploadId] = task

        // 4. Perform Upload
        do {
            let speechId = try await performUpload(
                endpoint: .uploadSpeech,
                fileURL: fileURL,
                metadata: metadata,
                uploadId: uploadId,
                progressHandler: progressHandler
            )

            // Track upload completed
            let duration = Date().timeIntervalSince(uploadStartTime)
            AnalyticsService.shared.logUploadCompleted(
                speechId: nil,
                duration: duration,
                fileSizeMB: fileSizeMB
            )

            return speechId
        } catch {
            // Track upload failed
            AnalyticsService.shared.logUploadFailed(
                speechId: nil,
                reason: error.localizedDescription,
                retryCount: 0
            )
            throw error
        }
    }

    private func performUpload(
        endpoint: Endpoint,
        fileURL: URL,
        metadata: [String: Any],
        uploadId: UUID,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> String {
        do {
            let response = try await apiClient.upload(
                endpoint: endpoint,
                fileURL: fileURL,
                metadata: metadata,
                progressHandler: progressHandler
            )
            
            // Success: Remove persistent request
            await deleteRequest(id: uploadId)
            activeUploads.removeValue(forKey: uploadId)
            
            return response.speechId
            
        } catch {
            // Retry logic
            if let networkError = error as? NetworkError, networkError.isRetriable {
                return try await retryUpload(
                    endpoint: endpoint,
                    fileURL: fileURL,
                    metadata: metadata,
                    uploadId: uploadId,
                    progressHandler: progressHandler,
                    attemptNumber: 1
                )
            }
            
            // Remove from active tracking but potentially keep in DB for manual retry later?
            // For now, removing from activeUploads is key for UI.
            activeUploads.removeValue(forKey: uploadId)
            throw error
        }
    }

    private func retryUpload(
        endpoint: Endpoint,
        fileURL: URL,
        metadata: [String: Any],
        uploadId: UUID,
        progressHandler: @escaping (Double) -> Void,
        attemptNumber: Int
    ) async throws -> String {
        guard attemptNumber <= Constants.API.maxRetryAttempts else {
            activeUploads.removeValue(forKey: uploadId)
            AnalyticsService.shared.logUploadFailed(
                speechId: nil,
                reason: "Max retry attempts reached",
                retryCount: attemptNumber
            )
            throw NetworkError.uploadFailed(reason: "Max retry attempts reached")
        }

        // Track retry attempt
        AnalyticsService.shared.logEvent(AnalyticsEvents.uploadRetried, parameters: [
            "retry_count": attemptNumber
        ])

        // Exponential backoff
        let delay = TimeInterval(pow(2.0, Double(attemptNumber - 1)))
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        print("Retrying upload (attempt \(attemptNumber + 1)) for \(uploadId)...")

        do {
            let response = try await apiClient.upload(
                endpoint: endpoint,
                fileURL: fileURL,
                metadata: metadata,
                progressHandler: progressHandler
            )

            await deleteRequest(id: uploadId)
            activeUploads.removeValue(forKey: uploadId)
            return response.speechId

        } catch {
            if let networkError = error as? NetworkError, networkError.isRetriable {
                return try await retryUpload(
                    endpoint: endpoint,
                    fileURL: fileURL,
                    metadata: metadata,
                    uploadId: uploadId,
                    progressHandler: progressHandler,
                    attemptNumber: attemptNumber + 1
                )
            }
            
            activeUploads.removeValue(forKey: uploadId)
            throw error
        }
    }
    
    // MARK: - Persistence Helpers
    
    private func deleteRequest(id: UUID) async {
        let context = dataController.backgroundContext()
        do {
            let predicate = #Predicate<UploadRequest> { $0.id == id }
            let descriptor = FetchDescriptor(predicate: predicate)
            if let request = try context.fetch(descriptor).first {
                context.delete(request)
                try context.save()
            }
        } catch {
            print("Failed to delete UploadRequest: \(error)")
        }
    }
    
    private func resumePendingUploads() async {
        print("Checking for pending uploads...")
        let context = dataController.backgroundContext()
        
        do {
            let descriptor = FetchDescriptor<UploadRequest>(sortBy: [SortDescriptor(\.createdAt)])
            let pendingRequests = try context.fetch(descriptor)
            
            guard !pendingRequests.isEmpty else { return }
            print("Found \(pendingRequests.count) pending uploads. Resuming...")
            
            for request in pendingRequests {
                if !FileManager.default.fileExists(atPath: request.fileURL.path) {
                    context.delete(request)
                } else {
                    print("Pending upload found for \(request.id). Will be retried when user initiates, or we could auto-retry here.")
                }
            }
            try context.save()
            
        } catch {
            print("Failed to fetch pending uploads: \(error)")
        }
    }

    // MARK: - Upload Management

    func cancelUpload(for recordingId: UUID) {
        if let task = activeUploads[recordingId] {
            task.uploadTask?.cancel() 
            activeUploads.removeValue(forKey: recordingId)
        }
        
        Task {
            await deleteRequest(id: recordingId)
        }
    }

    func isUploading(recordingId: UUID) -> Bool {
        activeUploads[recordingId] != nil
    }

    // MARK: - Helper Types

    private struct UploadTask {
        let id: UUID
        let fileURL: URL
        var progress: Double = 0.0
        var uploadTask: URLSessionTask? = nil
    }
}

extension UploadService: UploadServicing {}

// MARK: - Duration Helpers

private extension UploadService {
    func ensureDuration(for recording: SpeechRecording, fileURL: URL) async -> Int {
        if recording.durationSeconds > 0 {
            return recording.durationSeconds
        }

        let asset = AVURLAsset(url: fileURL)
        
        do {
            let duration: CMTime
            if #available(iOS 16.0, *) {
                duration = try await asset.load(.duration)
            } else {
                duration = asset.duration
            }
            
            let seconds = CMTimeGetSeconds(duration)
            if seconds.isFinite, seconds > 0 {
                let rounded = max(1, Int(round(seconds)))
                recording.durationSeconds = rounded
                return rounded
            }
        } catch {
            print("Failed to load asset duration: \(error)")
        }

        if let audioPlayer = try? AVAudioPlayer(contentsOf: fileURL) {
            let duration = audioPlayer.duration
            if duration.isFinite, duration > 0 {
                let rounded = max(1, Int(round(duration)))
                recording.durationSeconds = rounded
                return rounded
            }
        }

        return 0
    }
}
