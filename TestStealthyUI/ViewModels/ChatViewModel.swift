//
//  ChatViewModel.swift
//  TestStealthyUI
//
//  Migrated from StealthyAI-macOS with archive support added
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

    // Rename state (for modal sheet - can be ignored if using inline)
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

    // MARK: - Draft Conversation State

    /// Represents a draft conversation that hasn't been persisted yet
    struct DraftConversation {
        let tempID: UUID
        let title: String

        init(title: String = "New Conversation") {
            self.tempID = UUID()
            self.title = title
        }
    }

    /// Current draft conversation (if any). Not persisted until first message is sent.
    @Published var draftConversation: DraftConversation? = nil

    private let pairingService: PairingService = DefaultPairingService()

    var selectedIndex: Int? {
        guard let selectedID = selectedID else { return nil }
        return conversations.firstIndex(where: { $0.id == selectedID })
    }

    var selectedConversation: Conversation? {
        guard let selectedID = selectedID else { return nil }
        return conversations.first(where: { $0.id == selectedID })
    }

    // Computed property for current model name (placeholder)
    var currentModelName: String {
        "Claude 3.5 Sonnet"
    }

    init() {
        // Load conversations from disk
        let loaded = ConversationStore.load()

        conversations = loaded
        selectedID = nil  // Don't auto-select - let user choose or start a draft
    }

    // MARK: - Persistence

    func saveConversations() {
        ConversationStore.save(conversations)
    }

    // MARK: - Messaging

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""

        // If we're in a draft, commit it with this first message
        if isViewingDraft {
            guard let conversationID = commitDraft(withFirstMessage: text) else { return }

            // Find the newly created conversation and simulate reply
            if let idx = conversations.firstIndex(where: { $0.id == conversationID }) {
                simulateAssistantReply(at: idx, userMessage: text)
            }
            return
        }

        // Normal message sending for existing conversations
        guard let idx = selectedIndex else { return }

        // If this is the first user message in this conversation, set the title from it (max 30 chars + ellipsis)
        if conversations[idx].messages.isEmpty {
            let base = String(text.prefix(30))
            let newTitle = text.count > 30 ? base + "..." : base
            if !newTitle.isEmpty {
                conversations[idx].title = newTitle
            }
        }

        // Append user message (mutate in place)
        conversations[idx].messages.append(Message(content: text, role: .user))
        conversations[idx].updatedAt = Date()
        saveConversations()

        // Simulate assistant reply with streaming
        simulateAssistantReply(at: idx, userMessage: text)
    }

    private func simulateAssistantReply(at idx: Int, userMessage: String) {
        // Simulate assistant reply with streaming
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))

            // Re-check idx validity
            guard conversations.indices.contains(idx) else { return }

            // Start with empty assistant message
            let assistantMessage = Message(content: "", role: .assistant)
            conversations[idx].messages.append(assistantMessage)
            let messageIndex = conversations[idx].messages.count - 1

            // Simulate streaming response
            let response = "You said: \(userMessage)"
            for ch in response {
                try? await Task.sleep(nanoseconds: 25_000_000)
                guard conversations.indices.contains(idx),
                      conversations[idx].messages.indices.contains(messageIndex) else { return }
                conversations[idx].messages[messageIndex].content.append(ch)
            }

            conversations[idx].updatedAt = Date()
            saveConversations()
        }
    }

    // MARK: - Conversation Management

    /// Start a new conversation as a draft (not persisted until first message)
    func startNewConversationDraft() {
        // Discard any existing draft first
        discardDraftIfEmpty()

        // Create new draft
        let draft = DraftConversation()
        draftConversation = draft

        // Set selectedID to draft's tempID so routing works
        selectedID = draft.tempID
    }

    /// Create and select a new empty conversation immediately (persisted)
    @discardableResult
    func createEmptyConversation(title: String = "New Conversation") -> UUID {
        let newConversation = Conversation(title: title, messages: [])
        conversations.insert(newConversation, at: 0)
        selectedID = newConversation.id
        saveConversations()
        return newConversation.id
    }

    /// Delete the given conversation if it contains no messages
    func deleteIfEmpty(id: Conversation.ID) {
        guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        if conversations[idx].messages.isEmpty {
            deleteConversation(id: id)
        }
    }

    /// Commit the current draft with the first user message
    /// - Parameter firstMessage: The first message content
    /// - Returns: The ID of the newly created conversation
    @discardableResult
    func commitDraft(withFirstMessage firstMessage: String) -> UUID? {
        guard let draft = draftConversation else { return nil }

        let trimmed = firstMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let base = String(trimmed.prefix(30))
        let computedTitle = trimmed.count > 30 ? base + "..." : base
        let newConversation = Conversation(
            title: computedTitle.isEmpty ? draft.title : computedTitle,
            messages: [Message(content: trimmed, role: .user)]
        )

        // Add to conversations list
        conversations.insert(newConversation, at: 0)

        // Set as selected
        selectedID = newConversation.id

        // Clear draft
        draftConversation = nil

        // Persist
        saveConversations()

        return newConversation.id
    }

    /// Discard the current draft without persisting
    func discardDraftIfEmpty() {
        guard draftConversation != nil else { return }
        draftConversation = nil
        // Don't change selectedID here - let the caller handle navigation
    }

    /// Check if we're currently viewing a draft
    var isViewingDraft: Bool {
        guard let draft = draftConversation else { return false }
        return selectedID == draft.tempID
    }

    // Rename conversation by ID (used by inline rename in sidebar)
    func renameConversation(id: Conversation.ID, to newTitle: String) {
        guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        conversations[idx].title = trimmed
        conversations[idx].updatedAt = Date()
        saveConversations()
    }

    // MARK: - Archive Management (NEW)

    func archiveConversation(id: Conversation.ID) {
        guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[idx].isArchived = true
        conversations[idx].updatedAt = Date()

        // If archiving the selected conversation, deselect it
        if selectedID == id {
            selectedID = nil
        }

        saveConversations()
    }

    func unarchiveConversation(id: Conversation.ID) {
        guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[idx].isArchived = false
        conversations[idx].updatedAt = Date()
        saveConversations()
    }

    // MARK: - Flagging

    func flagConversation(id: Conversation.ID, color: FlagColor? = .orange) {
        guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[idx].flaggedAt = Date()
        conversations[idx].flagColor = color
        conversations[idx].updatedAt = Date()
        saveConversations()
    }

    func unflagConversation(id: Conversation.ID) {
        guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[idx].flaggedAt = nil
        conversations[idx].flagColor = nil
        conversations[idx].updatedAt = Date()
        saveConversations()
    }

    // MARK: - Delete Management

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
            // Find next non-archived conversation
            let nonArchived = conversations.filter { !$0.isArchived && $0.id != id }
            if let next = nonArchived.first {
                selectedID = next.id
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

