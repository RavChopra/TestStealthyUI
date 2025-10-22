//
//  ProjectDetailView.swift
//  TestStealthyUI
//
//  Detail view for an individual project with real conversation management
//

import SwiftUI

// MARK: - Project Empty State (when no conversations exist)
private struct ProjectEmptyState: View {
    @State private var currentGreetingIndex = 0

    private let greetings = [
        "What's on your mind?",
        "How can I help you today?",
        "Ready when you are",
        "Let's get started",
        "What would you like to explore?"
    ]

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.secondary)
            Text(greetings[currentGreetingIndex])
                .font(.title3)
                .foregroundStyle(.secondary)
                .id(currentGreetingIndex)
        }
        .onAppear {
            currentGreetingIndex = Int.random(in: 0..<greetings.count)
        }
    }
}

// MARK: - Project Draft Placeholder (for new conversations)
private struct ProjectDraftPlaceholder: View {
    @State private var currentGreetingIndex = 0

    private let greetings = [
        "What's on your mind?",
        "How can I help you today?",
        "Ready when you are",
        "Let's get started",
        "What would you like to explore?"
    ]

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.secondary)
            Text(greetings[currentGreetingIndex])
                .font(.title2)
                .foregroundStyle(.secondary)
                .id(currentGreetingIndex)
            Text("Type your first message below")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .onAppear {
            currentGreetingIndex = Int.random(in: 0..<greetings.count)
        }
    }
}

// MARK: - Grouped Message Row
private struct GroupedMessageRow: View {
    let message: Message
    let isGroupedWithPrevious: Bool
    let maxBubbleWidth: CGFloat

    var body: some View {
        MessageRow(
            text: message.content,
            isUser: message.role == .user,
            maxBubbleWidth: maxBubbleWidth
        )
        .padding(.top, isGroupedWithPrevious ? 4 : 10)
    }
}

// MARK: - Chat Messages List
private struct ChatMessagesList: View {
    let messages: [Message]

    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width - 40
            let userMaxWidth = min(520, max(240, availableWidth * 0.55))
            let assistantMaxWidth = min(720, max(240, availableWidth * 0.70))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages.indices, id: \.self) { idx in
                            let message = messages[idx]
                            let previous = idx > 0 ? messages[idx - 1] : nil
                            let grouped = (previous?.role == message.role)

                            GroupedMessageRow(
                                message: message,
                                isGroupedWithPrevious: grouped,
                                maxBubbleWidth: message.role == .user ? userMaxWidth : assistantMaxWidth
                            )
                            .id(message.id)
                        }
                    }
                    .frame(width: geo.size.width, alignment: .leading)
                    .padding(.vertical, 24)
                }
                .frame(maxWidth: .infinity)
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Project Detail View
struct ProjectDetailView: View {
    @Binding var project: Project
    @EnvironmentObject var appStore: AppStore
    @State private var activeConversationID: UUID? = nil
    @State private var showConversationDeleteConfirm: Bool = false
    @State private var deleteTargetConversationID: UUID? = nil
    @State private var showProjectDeleteConfirm: Bool = false
    @State private var projectDeleteRequested: Bool = false

    var onBack: () -> Void
    var onDelete: () -> Void
    var onEdit: (Project) -> Void
    var onToggleFavorite: () -> Void

    @State private var input: String = ""
    @State private var showingNewConversationPrompt: Bool = false
    @State private var newConversationTitle: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if activeConversationID == nil {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: project.iconSymbol ?? "folder.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(project.iconColor?.color ?? .primary)
                            .padding(.trailing, 6)
                        Text(project.title)
                            .font(.largeTitle).bold()
                        Spacer()
                        Menu {
                            Button {
                                onToggleFavorite()
                            } label: {
                                Label(project.flaggedAt == nil ? "Flag" : "Unflag", systemImage: project.flaggedAt == nil ? "flag.fill" : "flag")
                            }
                            Divider()
                            Button { onEdit(project) } label: { Label("Edit", systemImage: "pencil") }
                            Divider()
                            Button(role: .destructive) {
                                showProjectDeleteConfirm = true
                            } label: { Label("Delete", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis")
                                .imageScale(.large)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .menuIndicator(.hidden)
                        .buttonStyle(.borderless)
                    }
                    if !project.description.isEmpty {
                        Text(project.description)
                            .foregroundStyle(.secondary)
                    }

                    // Tags display
                    if !project.tags.isEmpty {
                        TagsFlowView(tags: project.tags)
                            .padding(.top, 8)
                    }
                }
                .padding(.bottom, 16)

                // Conversations list within project
                VStack(alignment: .leading, spacing: 12) {
                    let visibleConvos = project.conversations.filter { !$0.isArchived }

                    if visibleConvos.isEmpty {
                        ProjectEmptyState()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    } else {
                        Text("Conversations")
                            .font(.headline)

                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(visibleConvos) { convo in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(convo.title)
                                            .font(.body)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                        Text("Updated \(relativeDate(convo.updatedAt))")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    Menu {
                                        Button("Rename") {
                                            // Prompt rename via alert for now
                                            promptRename(conversationID: convo.id)
                                        }
                                        Button(convo.isArchived ? "Unarchive" : "Archive") {
                                            if convo.isArchived {
                                                appStore.unarchiveConversation(projectID: project.id, conversationID: convo.id)
                                            } else {
                                                appStore.archiveConversation(projectID: project.id, conversationID: convo.id)
                                            }
                                        }
                                        Divider()
                                        Button("Delete", role: .destructive) {
                                            deleteTargetConversationID = convo.id
                                            showConversationDeleteConfirm = true
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .frame(width: 32, height: 32)
                                            .contentShape(Rectangle())
                                    }
                                    .menuIndicator(.hidden)
                                    .buttonStyle(.borderless)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.secondary.opacity(0.08))
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .onTapGesture {
                                    activeConversationID = convo.id
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            } else if let activeID = activeConversationID {
                // Show chat for active conversation or draft placeholder
                if let convo = project.conversations.first(where: { $0.id == activeID }) {
                    ChatMessagesList(messages: convo.messages)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    // Draft mode - conversation not created yet, show placeholder
                    ProjectDraftPlaceholder()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                }
            }
        }
        .padding(.horizontal, activeConversationID == nil ? 24 : 0)
        .padding(.vertical, activeConversationID == nil ? 20 : 0)
        .navigationTitle(activeConversationID == nil ? "" : project.title)
        .toolbar {
#if os(macOS)
            // Place both buttons on the leading side together
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 8) {
                    Button {
                        if activeConversationID != nil {
                            activeConversationID = nil
                        } else {
                            onBack()
                        }
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .help("Back")

                    Button {
                        // Create a draft by setting a temporary UUID
                        // The conversation will be created on first message send
                        activeConversationID = UUID()
                    } label: {
                        Label("New Conversation", systemImage: "square.and.pencil")
                    }
                    .help("New Conversation")
                }
            }
#else
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 8) {
                    Button {
                        if activeConversationID != nil {
                            activeConversationID = nil
                        } else {
                            onBack()
                        }
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }

                    Button {
                        // Create a draft by setting a temporary UUID
                        // The conversation will be created on first message send
                        activeConversationID = UUID()
                    } label: {
                        Label("New Conversation", systemImage: "square.and.pencil")
                    }
                }
            }
#endif
        }
#if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                TextField(activeConversationID == nil ? "Message \(project.title)" : "Message", text: $input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...12)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.secondary.opacity(0.15))
                    )
                    .onSubmit(sendMessage)

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .imageScale(.medium)
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.clear)
        }
        .alert("Delete Conversation?", isPresented: $showConversationDeleteConfirm) {
            Button("Cancel", role: .cancel) {
                deleteTargetConversationID = nil
            }
            Button("Delete", role: .destructive) {
                if let id = deleteTargetConversationID {
                    // If deleting the active conversation, go back to list
                    if activeConversationID == id {
                        activeConversationID = nil
                    }
                    appStore.deleteConversation(projectID: project.id, conversationID: id)
                }
                deleteTargetConversationID = nil
            }
        } message: {
            if let id = deleteTargetConversationID,
               let convo = project.conversations.first(where: { $0.id == id }) {
                Text("Are you sure you want to delete \"\(convo.title)\"? This action cannot be undone.")
            } else {
                Text("This action cannot be undone.")
            }
        }
        .alert("Delete Project?", isPresented: $showProjectDeleteConfirm) {
            Button("Cancel", role: .cancel) {
                showProjectDeleteConfirm = false
            }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \"\(project.title)\"? This action cannot be undone.")
        }
        .alert("New Conversation", isPresented: $showingNewConversationPrompt) {
            TextField("Conversation title", text: $newConversationTitle)
            Button("Cancel", role: .cancel) {
                newConversationTitle = ""
            }
            Button("Create") {
                createNewConversation()
            }
        } message: {
            Text("Enter a title for this conversation")
        }
    }

    // MARK: - Actions

    private func createNewConversation() {
        let title = newConversationTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        if let conversationID = appStore.createConversation(projectID: project.id, title: title) {
            activeConversationID = conversationID
        }

        newConversationTitle = ""
    }

    private func sendMessage() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Check if we need to create a new conversation (either no ID or draft ID)
        if activeConversationID == nil {
            // Create a new conversation on first send
            if let newConvoID = appStore.createConversation(projectID: project.id, title: "New Conversation") {
                activeConversationID = newConvoID
            }
        } else if let tempID = activeConversationID,
                  project.conversations.first(where: { $0.id == tempID }) == nil {
            // Draft mode: activeConversationID is set but conversation doesn't exist yet
            // Create the conversation now with the first message
            if let newConvoID = appStore.createConversation(projectID: project.id, title: "New Conversation") {
                activeConversationID = newConvoID
            }
        }

        guard let convoID = activeConversationID else { return }

        // Append user message
        appStore.addMessage(projectID: project.id, conversationID: convoID, content: trimmed, role: .user)
        input = ""

        // Simulated assistant reply
        let fullResponse = "You said: \(trimmed)"
        startTypingProject(response: fullResponse, convoID: convoID)
    }

    private func startTypingProject(response: String, convoID: UUID) {
        // Append an empty assistant message then stream characters
        appStore.addMessage(projectID: project.id, conversationID: convoID, content: "", role: .assistant)

        Task {
            for ch in response {
                try? await Task.sleep(nanoseconds: 25_000_000)
                await MainActor.run {
                    // Update last assistant message content
                    if let pIdx = appStore.projects.firstIndex(where: { $0.id == project.id }),
                       let cIdx = appStore.projects[pIdx].conversations.firstIndex(where: { $0.id == convoID }),
                       let mIdx = appStore.projects[pIdx].conversations[cIdx].messages.indices.last {
                        appStore.projects[pIdx].conversations[cIdx].messages[mIdx].content.append(ch)
                        appStore.projects[pIdx].conversations[cIdx].updatedAt = Date()
                        appStore.projects[pIdx].updatedAt = Date()
                    }
                }
            }
        }
    }

    private func promptRename(conversationID: UUID) {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Rename Conversation"
        alert.informativeText = "Enter a new title for the conversation."
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        alert.accessoryView = inputField
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            appStore.renameConversation(projectID: project.id, conversationID: conversationID, to: inputField.stringValue)
        }
        #endif
    }
    
    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

