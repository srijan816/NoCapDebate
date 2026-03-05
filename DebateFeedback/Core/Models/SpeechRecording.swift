//
//  SpeechRecording.swift
//  DebateFeedback
//
//
//

import Foundation
import SwiftData

@Model
final class SpeechRecording {
    var id: UUID
    var speakerName: String
    var speakerPosition: String
    var localFilePath: String
    var durationSeconds: Int
    var uploadStatus: UploadStatus
    var processingStatus: ProcessingStatus
    var transcriptionStatus: ProcessingStatus
    var feedbackStatus: ProcessingStatus
    var feedbackUrl: String?
    var speechId: String? // Backend speech ID for fetching feedback
    var feedbackContent: String? // Cached feedback content
    var transcriptUrl: String?
    var transcriptText: String?
    var transcriptionErrorMessage: String?
    var feedbackErrorMessage: String?
    var recordedAt: Date
    var uploadProgress: Double
    var playableMomentsData: Data?

    var playableMoments: [PlayableMoment] {
        get {
            guard let data = playableMomentsData else { return [] }
            return (try? JSONDecoder().decode([PlayableMoment].self, from: data)) ?? []
        }
        set {
            playableMomentsData = try? JSONEncoder().encode(newValue)
        }
    }

    // Relationships
    var debateSession: DebateSession?

    init(
        id: UUID = UUID(),
        speakerName: String,
        speakerPosition: String,
        localFilePath: String,
        durationSeconds: Int,
        debateSession: DebateSession? = nil
    ) {
        self.id = id
        self.speakerName = speakerName
        self.speakerPosition = speakerPosition
        self.localFilePath = localFilePath
        self.durationSeconds = durationSeconds
        self.uploadStatus = .pending
        self.processingStatus = .pending
        self.transcriptionStatus = .pending
        self.feedbackStatus = .pending
        self.recordedAt = Date()
        self.uploadProgress = 0.0
        self.debateSession = debateSession
    }
}

extension SpeechRecording {
    /// Returns a synthesized status that mirrors the slowest stage
    var aggregatedProcessingStatus: ProcessingStatus {
        if feedbackStatus == .failed || transcriptionStatus == .failed {
            return .failed
        }

        if feedbackStatus == .complete {
            return .complete
        }

        if feedbackStatus == .processing || transcriptionStatus == .complete {
            return .processing
        }

        if transcriptionStatus == .processing {
            return .processing
        }

        return .pending
    }

    func updateAggregatedStatus() {
        processingStatus = aggregatedProcessingStatus
    }

    var failureDetails: String? {
        if transcriptionStatus == .failed {
            return transcriptionErrorMessage ?? "Transcription failed"
        }
        if feedbackStatus == .failed {
            return feedbackErrorMessage ?? "Feedback generation failed"
        }
        return nil
    }
}

enum UploadStatus: String, Codable {
    case pending
    case uploading
    case uploaded
    case failed

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .uploading: return "Uploading..."
        case .uploaded: return "Uploaded"
        case .failed: return "Failed"
        }
    }

    var isComplete: Bool {
        self == .uploaded
    }
}

enum ProcessingStatus: String, Codable {
    case pending
    case processing
    case complete
    case failed

    init(apiStatus: String?) {
        guard let value = apiStatus?.lowercased() else {
            self = .pending
            return
        }

        switch value {
        case "processing", "running", "in_progress":
            self = .processing
        case "complete", "completed", "done":
            self = .complete
        case "failed", "error":
            self = .failed
        default:
            self = .pending
        }
    }

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing..."
        case .complete: return "Complete"
        case .failed: return "Failed"
        }
    }

    var isComplete: Bool {
        self == .complete
    }
}

struct PlayableMoment: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let timestampLabel: String
    let timestampSeconds: Double
    let endTimestampSeconds: Double?
    let summary: String
    /// Prescriptive coaching advice for this moment (what to do differently next time)
    let recommendation: String?
    /// Coaching category (e.g. incomplete_argument, excellent, strategic_win)
    let category: String?
    /// Whether this is a praise or critical moment
    let severity: String?

    enum CodingKeys: String, CodingKey {
        case timestampLabel = "timestamp_label"
        case timestampSeconds = "timestamp_seconds"
        case summary = "issue"
        case endTimestampSeconds = "end_timestamp_seconds"
        case recommendation = "recommendation"
        case category = "category"
        case severity = "severity"
    }

    init(timestampLabel: String, timestampSeconds: Double, endTimestampSeconds: Double? = nil, summary: String, recommendation: String? = nil, category: String? = nil, severity: String? = nil) {
        self.timestampLabel = timestampLabel
        self.timestampSeconds = timestampSeconds
        self.endTimestampSeconds = endTimestampSeconds
        self.summary = summary
        self.recommendation = recommendation
        self.category = category
        self.severity = severity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let label = try container.decodeIfPresent(String.self, forKey: .timestampLabel) ?? "0:00"
        timestampLabel = label

        let startSeconds = try container.decodeIfPresent(Double.self, forKey: .timestampSeconds) ?? 0.0
        timestampSeconds = startSeconds

        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? "Feedback Point"
        recommendation = try container.decodeIfPresent(String.self, forKey: .recommendation)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        severity = try container.decodeIfPresent(String.self, forKey: .severity)

        // Check for explicit end time from backend
        if let explicitEnd = try container.decodeIfPresent(Double.self, forKey: .endTimestampSeconds) {
            endTimestampSeconds = explicitEnd
        } else {
            // Attempt to parse range from label (e.g. "0:30-1:00" or "0:30 to 1:00")
            endTimestampSeconds = PlayableMoment.parseEndTime(from: label)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestampLabel, forKey: .timestampLabel)
        try container.encode(timestampSeconds, forKey: .timestampSeconds)
        try container.encode(summary, forKey: .summary)
        try container.encodeIfPresent(endTimestampSeconds, forKey: .endTimestampSeconds)
        try container.encodeIfPresent(recommendation, forKey: .recommendation)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(severity, forKey: .severity)
    }

    /// True if this moment is praise (excellent/strategic_win/proved), false if coaching critique
    var isPraise: Bool {
        guard let s = severity else { return false }
        return s == "praise"
    }
    
    // Helper to parse end time from strings like "0:30-1:00" or "0:30 to 1:00"
    private static func parseEndTime(from label: String) -> Double? {
        let separators = ["-", " to "]
        for separator in separators {
            if label.contains(separator) {
                let parts = label.components(separatedBy: separator)
                if parts.count == 2 {
                    let endString = parts[1].trimmingCharacters(in: .whitespaces)
                    return PlayableMoment.timeInterval(from: endString)
                }
            }
        }
        return nil
    }
    
    private static func timeInterval(from timeString: String) -> Double? {
        let parts = timeString.split(separator: ":").compactMap { Double($0) }
        guard parts.count >= 2 else { return nil }

        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        } else if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        return nil
    }
}
