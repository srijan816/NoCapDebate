//
//  DebateSession.swift
//  DebateFeedback
//
//

import Foundation
import SwiftData

@Model
final class DebateSession {
    var id: UUID
    var motion: String
    var format: DebateFormat
    var studentLevel: StudentLevel
    var speechTimeSeconds: Int
    var replyTimeSeconds: Int?
    var createdAt: Date
    var isGuestMode: Bool
    var classId: String?
    var scheduleId: String?

    // Backend integration
    var backendDebateId: String? // The debate ID from the backend API

    // Team composition stored as JSON-encoded data
    var teamCompositionData: Data?

    // Relationships
    var teacher: Teacher?
    var students: [Student]?

    @Relationship(deleteRule: .cascade, inverse: \SpeechRecording.debateSession)
    var speechRecordings: [SpeechRecording]?

    init(
        id: UUID = UUID(),
        motion: String,
        format: DebateFormat,
        studentLevel: StudentLevel,
        speechTimeSeconds: Int,
        replyTimeSeconds: Int? = nil,
        isGuestMode: Bool = false,
        teacher: Teacher? = nil,
        classId: String? = nil,
        scheduleId: String? = nil
    ) {
        self.id = id
        self.motion = motion
        self.format = format
        self.studentLevel = studentLevel
        self.speechTimeSeconds = speechTimeSeconds
        self.replyTimeSeconds = replyTimeSeconds
        self.isGuestMode = isGuestMode
        self.createdAt = Date()
        self.teacher = teacher
        self.classId = classId
        self.scheduleId = scheduleId
    }

    // Helper to work with team composition
    var teamComposition: TeamComposition? {
        get {
            guard let data = teamCompositionData else { return nil }
            return try? JSONDecoder().decode(TeamComposition.self, from: data)
        }
        set {
            teamCompositionData = try? JSONEncoder().encode(newValue)
        }
    }
}

enum DebateFormat: String, Codable, CaseIterable {
    case wsdc = "WSDC"
    case bp = "BP"
    case ap = "AP"
    case australs = "Australs"

    var displayName: String { rawValue }

    var defaultSpeechTime: Int {
        switch self {
        case .wsdc: return 480 // 8 minutes
        case .bp: return 420 // 7 minutes
        case .ap: return 360 // 6 minutes
        case .australs: return 480 // 8 minutes
        }
    }

    var hasReplySpeeches: Bool {
        switch self {
        case .wsdc, .australs: return true
        case .bp, .ap: return false
        }
    }

    var defaultReplyTime: Int? {
        switch self {
        case .wsdc: return 240 // 4 minutes
        case .australs: return 180 // 3 minutes
        case .bp, .ap: return nil
        }
    }

    var teamStructure: TeamStructure {
        switch self {
        case .wsdc, .australs:
            return .propOpp
        case .bp:
            return .britishParliamentary
        case .ap:
            return .asianParliamentary
        }
    }
}

enum TeamStructure {
    case propOpp // Prop/Opp (3v3)
    case britishParliamentary // OG, OO, CG, CO (2 per team)
    case asianParliamentary // Government/Opposition (2v2)
}

struct TeamComposition: Codable {
    // Standard 3v3 formats
    var prop: [String]? // Student IDs
    var opp: [String]?
    var propReply: String?
    var oppReply: String?

    // British Parliamentary
    var og: [String]?
    var oo: [String]?
    var cg: [String]?
    var co: [String]?

    // Helper to get all speaker positions in order
    func getSpeakerOrder(format: DebateFormat) -> [(studentId: String, position: String)] {
        switch format {
        case .wsdc, .australs:
            // Alternate between Prop and Opp: Prop 1, Opp 1, Prop 2, Opp 2, Prop 3, Opp 3
            var speakers: [(String, String)] = []
            let propSpeakers = prop ?? []
            let oppSpeakers = opp ?? []
            let maxMain = max(min(propSpeakers.count, 3), min(oppSpeakers.count, 3))

            for i in 0..<maxMain {
                if i < propSpeakers.count {
                    speakers.append((propSpeakers[i], "Prop \(i + 1)"))
                }
                if i < oppSpeakers.count {
                    speakers.append((oppSpeakers[i], "Opp \(i + 1)"))
                }
            }

            let resolvedPropReply = propSpeakers.count >= 4 ? propSpeakers[3] : propReply
            let resolvedOppReply = oppSpeakers.count >= 4 ? oppSpeakers[3] : oppReply

            if let oppReply = resolvedOppReply {
                speakers.append((oppReply, "Opp Reply"))
            }
            if let propReply = resolvedPropReply {
                speakers.append((propReply, "Prop Reply"))
            }
            return speakers

        case .bp:
            var speakers: [(String, String)] = []
            if let og = og {
                for (index, id) in og.enumerated() {
                    speakers.append((id, "OG \(index + 1)"))
                }
            }
            if let oo = oo {
                for (index, id) in oo.enumerated() {
                    speakers.append((id, "OO \(index + 1)"))
                }
            }
            if let cg = cg {
                for (index, id) in cg.enumerated() {
                    speakers.append((id, "CG \(index + 1)"))
                }
            }
            if let co = co {
                for (index, id) in co.enumerated() {
                    speakers.append((id, "CO \(index + 1)"))
                }
            }
            return speakers

        case .ap:
            // Alternate between Gov and Opp: Gov 1, Opp 1, Gov 2, Opp 2
            var speakers: [(String, String)] = []
            let govSpeakers = prop ?? []
            let oppSpeakers = opp ?? []
            let maxCount = max(govSpeakers.count, oppSpeakers.count)

            for i in 0..<maxCount {
                if i < govSpeakers.count {
                    speakers.append((govSpeakers[i], "Gov \(i + 1)"))
                }
                if i < oppSpeakers.count {
                    speakers.append((oppSpeakers[i], "Opp \(i + 1)"))
                }
            }
            return speakers
        }
    }
}
