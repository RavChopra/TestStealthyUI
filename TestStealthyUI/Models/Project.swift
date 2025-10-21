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

    init(id: UUID = UUID(), title: String, description: String, updatedAt: Date, flaggedAt: Date? = nil, flagColor: FlagColor? = nil, conversations: [Conversation] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.updatedAt = updatedAt
        self.flaggedAt = flaggedAt
        self.flagColor = flagColor
        self.conversations = conversations
    }
}
