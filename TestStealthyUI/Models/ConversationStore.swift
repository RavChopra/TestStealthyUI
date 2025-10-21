//
//  ConversationStore.swift
//  TestStealthyUI
//
//  Migrated from StealthyAI-macOS
//

import Foundation

/// Manages local persistence of conversations to disk
struct ConversationStore {
    private static let fileName = "conversations.json"

    /// Returns the URL for the conversations file in Application Support
    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("StealthyAI", isDirectory: true)
        return appFolder.appendingPathComponent(fileName)
    }

    /// Load conversations from disk
    /// - Returns: Array of conversations, or empty array if file doesn't exist or can't be decoded
    static func load() -> [Conversation] {
        let url = fileURL

        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            decoder.dateDecodingStrategy = .iso8601

            // Try versioned archive first
            if let archive = try? decoder.decode(ConversationsArchive.self, from: data) {
                return archive.conversations
            } else {
                // Fallback: legacy format was array of conversations
                let conversations = try decoder.decode([Conversation].self, from: data)
                return conversations
            }
        } catch {
            print("Failed to load conversations: \(error.localizedDescription)")
            return []
        }
    }

    /// Save conversations to disk
    /// - Parameter conversations: Array of conversations to save
    static func save(_ conversations: [Conversation]) {
        let url = fileURL

        // Ensure Application Support directory exists
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("StealthyAI", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

            // Encode with versioned archive format
            let archive = ConversationsArchive(version: 1, conversations: conversations)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(archive)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save conversations: \(error.localizedDescription)")
        }
    }
}
