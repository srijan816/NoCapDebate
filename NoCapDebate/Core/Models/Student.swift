//
//  Student.swift
//  DebateFeedback
//
//

import Foundation
import SwiftData

@Model
final class Student {
    var id: UUID
    var name: String
    var level: StudentLevel
    var createdAt: Date

    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \DebateSession.students)
    var debateSessions: [DebateSession]?

    init(id: UUID = UUID(), name: String, level: StudentLevel) {
        self.id = id
        self.name = name
        self.level = level
        self.createdAt = Date()
    }
}

enum StudentLevel: String, Codable, CaseIterable {
    case primary
    case secondary

    var displayName: String {
        switch self {
        case .primary: return "Primary"
        case .secondary: return "Secondary"
        }
    }
}
