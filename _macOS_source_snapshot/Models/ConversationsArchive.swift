//
//  ConversationsArchive.swift
//  StealthyAI-macOS
//
//  Created by Claude on 2025-09-30.
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
