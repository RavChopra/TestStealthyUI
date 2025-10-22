//
//  Conversation.swift
//  StealthyAI-macOS
//
//  Created by Claude on 2025-09-30.
//

@preconcurrency import Foundation

struct Conversation: Identifiable, Codable, Sendable {
    let id: UUID
    var title: String
    var messages: [Message]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, messages: [Message] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
