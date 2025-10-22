//
//  Project.swift
//  TestStealthyUI
//
//  Project model (preserved from original Models.swift)
//

import SwiftUI

// MARK: - Projects Model
enum FlagColor: String, CaseIterable, Codable, Equatable {
    case red, orange, yellow, green, blue, teal, purple, gray

    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .teal: return .teal
        case .purple: return .purple
        case .gray: return .gray
        }
    }

    var accessibilityName: String {
        switch self {
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .teal: return "Teal"
        case .purple: return "Purple"
        case .gray: return "Gray"
        }
    }
}

struct Project: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var description: String
    var updatedAt: Date
    var flaggedAt: Date?
    var flagColor: FlagColor?
    var conversations: [Conversation]
    var tags: [String]
    
    var iconSymbol: String?
    var iconColor: FlagColor?

    init(id: UUID = UUID(), title: String, description: String, updatedAt: Date, flaggedAt: Date? = nil, flagColor: FlagColor? = nil, conversations: [Conversation] = [], tags: [String] = [], iconSymbol: String? = "folder", iconColor: FlagColor? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.updatedAt = updatedAt
        self.flaggedAt = flaggedAt
        self.flagColor = flagColor
        self.conversations = conversations
        self.tags = tags
        self.iconSymbol = iconSymbol
        self.iconColor = iconColor
    }

    // MARK: - Codable

    /// Custom decoder to maintain backwards compatibility with older JSON that lacks new fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        flaggedAt = try container.decodeIfPresent(Date.self, forKey: .flaggedAt)
        flagColor = try container.decodeIfPresent(FlagColor.self, forKey: .flagColor)
        conversations = try container.decode([Conversation].self, forKey: .conversations)

        // Default to empty array if missing (backwards compatibility)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        iconSymbol = try container.decodeIfPresent(String.self, forKey: .iconSymbol) ?? "folder"
        iconColor = try container.decodeIfPresent(FlagColor.self, forKey: .iconColor)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, updatedAt, flaggedAt, flagColor, conversations, tags, iconSymbol, iconColor
    }
}

