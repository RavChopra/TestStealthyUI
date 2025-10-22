//
//  Conversation.swift
//  TestStealthyUI
//
//  Migrated from StealthyAI-macOS with archive and flagging features
//

@preconcurrency import Foundation
import SwiftUI

struct Conversation: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var title: String
    var messages: [Message]
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var flaggedAt: Date?  // NEW: Added for flagging functionality
    var flagColor: FlagColor?  // NEW: Added for flagging functionality

    init(id: UUID = UUID(), title: String, messages: [Message] = [], createdAt: Date = Date(), updatedAt: Date = Date(), isArchived: Bool = false, flaggedAt: Date? = nil, flagColor: FlagColor? = nil) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.flaggedAt = flaggedAt
        self.flagColor = flagColor
    }
}
