//
//  AppStore.swift
//  TestStealthyUI
//
//  Central store for all projects with automatic persistence
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AppStore: ObservableObject {
    @Published var projects: [Project] = [] {
        didSet {
            saveProjects()
        }
    }

    init() {
        // Load projects from disk
        let loaded = ProjectStore.load()

        if loaded.isEmpty {
            // Start with sample projects if no saved data
            projects = [
                Project(
                    title: "Test project",
                    description: "Testing the create project functionality",
                    updatedAt: Date().addingTimeInterval(-4*60),
                    conversations: []
                ),
                Project(
                    title: "StealthyAI",
                    description: "",
                    updatedAt: Date().addingTimeInterval(-19*24*3600),
                    conversations: []
                ),
                Project(
                    title: "How to use Claude",
                    description: "An example project that also doubles as a how-to guide for using Claude.",
                    updatedAt: Date().addingTimeInterval(-19*24*3600),
                    conversations: []
                )
            ]
            saveProjects()
        } else {
            projects = loaded
        }
    }

    // MARK: - Persistence

    func saveProjects() {
        ProjectStore.save(projects)
    }

    // MARK: - Project Management

    func createProject(title: String, description: String, iconSymbol: String? = "folder", iconColor: FlagColor? = nil) -> UUID {
        let newProject = Project(
            title: title,
            description: description,
            updatedAt: Date(),
            conversations: [],
            tags: [],
            iconSymbol: iconSymbol,
            iconColor: iconColor
        )
        projects.insert(newProject, at: 0)
        return newProject.id
    }

    func updateProject(id: UUID, title: String, description: String, tags: [String] = [], iconSymbol: String? = nil, iconColor: FlagColor? = nil) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[idx].title = title
        projects[idx].description = description
        projects[idx].updatedAt = Date()
        let cleaned = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let limited = Array(cleaned.prefix(10))
        projects[idx].tags = limited
        if iconSymbol != nil || iconColor != nil {
            projects[idx].iconSymbol = iconSymbol
            projects[idx].iconColor = iconColor
        }
    }

    func deleteProject(id: UUID) {
        projects.removeAll { $0.id == id }
    }

    func toggleProjectFlag(id: UUID) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        if projects[idx].flaggedAt == nil {
            projects[idx].flaggedAt = Date()
        } else {
            projects[idx].flaggedAt = nil
        }
    }

    // MARK: - Conversation Management

    func createConversation(projectID: UUID, title: String) -> UUID? {
        guard let idx = projects.firstIndex(where: { $0.id == projectID }) else { return nil }

        let newConversation = Conversation(
            title: title,
            messages: [],
            createdAt: Date(),
            updatedAt: Date(),
            isArchived: false
        )

        projects[idx].conversations.append(newConversation)
        projects[idx].updatedAt = Date()

        return newConversation.id
    }

    func addMessage(projectID: UUID, conversationID: UUID, content: String, role: MessageRole) {
        guard let projectIdx = projects.firstIndex(where: { $0.id == projectID }),
              let convIdx = projects[projectIdx].conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }

        // If this is the first message in the conversation, set the title from it (max 30 chars + ...)
        if projects[projectIdx].conversations[convIdx].messages.isEmpty {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let base = String(trimmed.prefix(30))
                let computed = trimmed.count > 30 ? base + "..." : base
                if !computed.isEmpty {
                    projects[projectIdx].conversations[convIdx].title = computed
                }
            }
        }

        let message = Message(content: content, role: role, timestamp: Date())
        projects[projectIdx].conversations[convIdx].messages.append(message)
        projects[projectIdx].conversations[convIdx].updatedAt = Date()
        projects[projectIdx].updatedAt = Date()
    }

    func deleteConversation(projectID: UUID, conversationID: UUID) {
        guard let projectIdx = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[projectIdx].conversations.removeAll { $0.id == conversationID }
        projects[projectIdx].updatedAt = Date()
    }

    func renameConversation(projectID: UUID, conversationID: UUID, to newTitle: String) {
        guard let pIdx = projects.firstIndex(where: { $0.id == projectID }),
              let cIdx = projects[pIdx].conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        projects[pIdx].conversations[cIdx].title = trimmed
        projects[pIdx].conversations[cIdx].updatedAt = Date()
        projects[pIdx].updatedAt = Date()
    }

    func archiveConversation(projectID: UUID, conversationID: UUID) {
        guard let pIdx = projects.firstIndex(where: { $0.id == projectID }),
              let cIdx = projects[pIdx].conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        projects[pIdx].conversations[cIdx].isArchived = true
        projects[pIdx].conversations[cIdx].updatedAt = Date()
        projects[pIdx].updatedAt = Date()
    }

    func unarchiveConversation(projectID: UUID, conversationID: UUID) {
        guard let pIdx = projects.firstIndex(where: { $0.id == projectID }),
              let cIdx = projects[pIdx].conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        projects[pIdx].conversations[cIdx].isArchived = false
        projects[pIdx].conversations[cIdx].updatedAt = Date()
        projects[pIdx].updatedAt = Date()
    }
}

