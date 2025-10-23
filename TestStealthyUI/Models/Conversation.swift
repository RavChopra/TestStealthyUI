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
    var flaggedAt: Date?  // Added for flagging functionality
    var flagColor: FlagColor?  // Added for flagging functionality
    var isPinned: Bool  // Added for pinning functionality
    var pinnedAt: Date?  // Added for pinning functionality
    var tags: [String] = []  // Defaults ensure backward-compatible decoding
    var iconSymbol: String?  // Conversation icon SF Symbol
    var iconColor: FlagColor?  // Conversation icon tint color

    init(id: UUID = UUID(), title: String, messages: [Message] = [], createdAt: Date = Date(), updatedAt: Date = Date(), isArchived: Bool = false, flaggedAt: Date? = nil, flagColor: FlagColor? = nil, isPinned: Bool = false, pinnedAt: Date? = nil, tags: [String] = [], iconSymbol: String? = nil, iconColor: FlagColor? = nil) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.flaggedAt = flaggedAt
        self.flagColor = flagColor
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
        self.tags = tags
        self.iconSymbol = iconSymbol
        self.iconColor = iconColor
    }
}
