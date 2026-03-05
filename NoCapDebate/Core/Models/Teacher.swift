//
//  Teacher.swift
//  DebateFeedback
//
//

import Foundation
import SwiftData

@Model
final class Teacher {
    var id: UUID
    var name: String
    var deviceId: String
    var authToken: String?
    var isAdmin: Bool
    var createdAt: Date

    // Relationships
    @Relationship(deleteRule: .cascade)
    var debateSessions: [DebateSession]?

    init(
        id: UUID = UUID(),
        name: String,
        deviceId: String,
        authToken: String? = nil,
        isAdmin: Bool = false
    ) {
        self.id = id
        self.name = name
        self.deviceId = deviceId
        self.authToken = authToken
        self.isAdmin = isAdmin
        self.createdAt = Date()
    }
}
