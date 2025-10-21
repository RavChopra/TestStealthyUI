//
//  ConversationsArchive.swift
//  TestStealthyUI
//
//  Migrated from StealthyAI-macOS
//

@preconcurrency import Foundation

/// Top-level schema for exporting/importing conversations
struct ConversationsArchive: Codable, Sendable {
    var version: Int = 1
    var conversations: [Conversation]

    init(version: Int = 1, conversations: [Conversation]) {
        self.version = version
        self.conversations = conversations
    }
}
