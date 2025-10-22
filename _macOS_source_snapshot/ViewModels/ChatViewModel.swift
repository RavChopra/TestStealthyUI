//
//  ChatViewModel.swift
//  StealthyAI-macOS
//
//  Created by Claude on 2025-09-30.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var selectedID: Conversation.ID?
    @Published var inputText: String = ""

    // Export/Import state
    @Published var isExporting: Bool = false
    @Published var isImporting: Bool = false
    @Published var exportDocument: ConversationsDocument?
    @Published var showImportConfirmation: Bool = false
    @Published var pendingImportDocument: ConversationsDocument?

    // Alert state
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""

    // Rename state
    @Published var showRenameSheet: Bool = false
    @Published var renameTargetID: Conversation.ID?
    @Published var renameDraft: String = ""

    // Delete confirmation state
    @Published var showDeleteConfirm: Bool = false
    @Published var deleteTargetID: Conversation.ID?

    // Pairing state (ephemeral)
    @Published var showPairingSheet: Bool = false
    @Published var pairingToken: UUID = UUID()
    @Published var pairingTokenExpiresAt: Date = Date().addingTimeInterval(90)
    @Published var pairingDeepLink: URL?
    @Published var pairingRegenerateDisabledUntil: Date = .distantPast

    private let pairingService: PairingService = DefaultPairingService()

    var selectedIndex: Int? {
        guard let selectedID = selectedID else { return nil }
        return conversations.firstIndex(where: { $0.id == selectedID })
    }

    init() {
        // Load conversations from disk
        let loaded = ConversationStore.load()

        if loaded.isEmpty {
            // Fall back to sample data if no saved conversations
            let sampleConvo1 = Conversation(
                title: "Sample Chat 1",
                messages: [
                    Message(content: "Hello!", role: .user),
                    Message(content: "Hi there! How can I help you today?", role: .assistant)
                ]
            )
            let sampleConvo2 = Conversation(title: "Sample Chat 2", messages: [])
            conversations = [sampleConvo1, sampleConvo2]
            selectedID = sampleConvo1.id
        } else {
            conversations = loaded
            selectedID = loaded.first?.id
        }
    }

    // MARK: - Persistence

    func saveConversations() {
        ConversationStore.save(conversations)
    }

    // MARK: - Messaging

    func send() {
        guard let idx = selectedIndex, !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let text = inputText
        inputText = ""

        // Append user message (mutate in place)
        conversations[idx].messages.append(Message(content: text, role: .user))
        conversations[idx].updatedAt = Date()
        saveConversations()

        // Simulate assistant reply after 0.4s
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))

            // Re-check idx validity
            guard conversations.indices.contains(idx) else { return }

            conversations[idx].messages.append(Message(content: "This is a placeholder reply from the assistant.", role: .assistant))
            conversations[idx].updatedAt = Date()
            saveConversations()
        }
    }

    // MARK: - Conversation Management

    func createConversation() {
        let newConversation = Conversation(
            title: "New Conversation",
            messages: []
        )
        conversations.append(newConversation)
        selectedID = newConversation.id
        saveConversations()

        // Trigger rename sheet for immediate rename
        requestRename(id: newConversation.id)
    }

    func requestRename(id: Conversation.ID) {
        guard let conversation = conversations.first(where: { $0.id == id }) else { return }
        renameTargetID = id
        renameDraft = conversation.title
        showRenameSheet = true
    }

    func confirmRename() {
        guard let targetID = renameTargetID,
              let idx = conversations.firstIndex(where: { $0.id == targetID }) else {
            cancelRename()
            return
        }

        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            conversations[idx].title = trimmed
            conversations[idx].updatedAt = Date()
            saveConversations()
        }

        cancelRename()
    }

    func cancelRename() {
        showRenameSheet = false
        renameTargetID = nil
        renameDraft = ""
    }

    func requestDelete(id: Conversation.ID) {
        deleteTargetID = id
        showDeleteConfirm = true
    }

    func confirmDelete() {
        guard let targetID = deleteTargetID else {
            cancelDelete()
            return
        }

        deleteConversation(id: targetID)
        cancelDelete()
    }

    func cancelDelete() {
        showDeleteConfirm = false
        deleteTargetID = nil
    }

    private func deleteConversation(id: Conversation.ID) {
        guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return }

        // If deleting the selected conversation, select another
        if selectedID == id {
            if conversations.count > 1 {
                // Select next, or previous if deleting last
                if idx < conversations.count - 1 {
                    selectedID = conversations[idx + 1].id
                } else if idx > 0 {
                    selectedID = conversations[idx - 1].id
                } else {
                    selectedID = nil
                }
            } else {
                selectedID = nil
            }
        }

        conversations.remove(at: idx)
        saveConversations()
    }

    // MARK: - Pairing

    func openPairingSheet() {
        setNewToken()
        showPairingSheet = true
    }

    func regeneratePairingToken() {
        // Throttle to prevent abuse
        let now = Date()
        guard now >= pairingRegenerateDisabledUntil else {
            return
        }

        setNewToken()
        pairingRegenerateDisabledUntil = now.addingTimeInterval(1)
    }

    func closePairingSheet() {
        showPairingSheet = false
    }

    private func setNewToken(ttl: TimeInterval = 90) {
        do {
            let token = try pairingService.generateToken(ttl: ttl)
            pairingToken = token.uuid
            pairingTokenExpiresAt = token.expiresAt

            let deepLink = try pairingService.deepLink(for: token)
            pairingDeepLink = deepLink
        } catch {
            // Fallback to basic token if service fails
            pairingToken = UUID()
            pairingTokenExpiresAt = Date().addingTimeInterval(ttl)
            pairingDeepLink = URL(string: "stealthyai://pair/\(pairingToken.uuidString)")
        }
    }

    // MARK: - Export/Import

    func startExport() {
        let archive = ConversationsArchive(version: 1, conversations: conversations)
        exportDocument = ConversationsDocument(archive: archive)
        isExporting = true
    }

    func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            displayAlert(
                title: "Export Successful",
                message: "\(conversations.count) conversation(s) exported to \(url.lastPathComponent)"
            )
        case .failure(let error):
            displayAlert(
                title: "Export Failed",
                message: "Could not export conversations: \(error.localizedDescription)"
            )
        }
    }

    func startImport() {
        isImporting = true
    }

    func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            // Request access to the security-scoped resource
            let ok = url.startAccessingSecurityScopedResource()
            guard ok else {
                displayAlert(
                    title: "Import Failed",
                    message: "App sandbox denied access to the selected file."
                )
                return
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            do {
                // Read raw data from the selected file URL and decode JSON directly
                let data = try Data(contentsOf: url)

                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .useDefaultKeys
                decoder.dateDecodingStrategy = .iso8601

                // Prefer decoding the top-level archive first
                let archive: ConversationsArchive
                if let decodedArchive = try? decoder.decode(ConversationsArchive.self, from: data) {
                    archive = decodedArchive
                } else {
                    // Fallback: legacy format was an array of conversations
                    let legacyConversations = try decoder.decode([Conversation].self, from: data)
                    archive = ConversationsArchive(version: 1, conversations: legacyConversations)
                }

                // Wrap decoded archive in our FileDocument for confirmation flow
                let document = ConversationsDocument(archive: archive)
                pendingImportDocument = document
                showImportConfirmation = true
            } catch {
                displayAlert(
                    title: "Import Failed",
                    message: "Could not import conversations: \(error.localizedDescription)"
                )
            }
        case .failure(let error):
            displayAlert(
                title: "Import Failed",
                message: "Could not import conversations: \(error.localizedDescription)"
            )
        }
    }

    func confirmImport() {
        guard let document = pendingImportDocument else { return }

        conversations = document.archive.conversations
        if let first = conversations.first {
            selectedID = first.id
        } else {
            selectedID = nil
        }
        saveConversations()

        displayAlert(
            title: "Import Successful",
            message: "Imported \(document.archive.conversations.count) conversation(s) (version \(document.archive.version))"
        )

        pendingImportDocument = nil
        showImportConfirmation = false
    }

    func cancelImport() {
        pendingImportDocument = nil
        showImportConfirmation = false
    }

    private func displayAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

