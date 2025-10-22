//
//  ConversationsDocument.swift
//  TestStealthyUI
//
//  Migrated from StealthyAI-macOS
//

@preconcurrency import Foundation
@preconcurrency import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var stealthyAIConversations: UTType {
        // Use a dynamic lookup for our custom type if it's declared in Info.plist; otherwise, fall back to JSON.
        UTType("app.stealthyai.conversations-json") ?? .json
    }
}

struct ConversationsDocument: FileDocument, Sendable {
    static var readableContentTypes: [UTType] { [.stealthyAIConversations, .json] }

    var archive: ConversationsArchive

    init(archive: ConversationsArchive) {
        self.archive = archive
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        decoder.dateDecodingStrategy = .iso8601

        // Decode the top-level archive format
        self.archive = try decoder.decode(ConversationsArchive.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(archive)
        return FileWrapper(regularFileWithContents: data)
    }
}
