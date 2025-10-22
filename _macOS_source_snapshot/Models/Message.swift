//
//  Message.swift
//  StealthyAI-macOS
//
//  Created by Claude on 2025-09-30.
//

@preconcurrency import Foundation

struct Message: Identifiable, Codable, Sendable {
    let id: UUID
    var content: String
    var role: MessageRole
    var timestamp: Date

    init(id: UUID = UUID(), content: String, role: MessageRole, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
    }
}

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}
