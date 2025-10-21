//
//  SidebarView.swift
//  TestStealthyUI
//
//  Updated to use ChatViewModel with inline rename, archive, and flagging UX
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Binding var projects: [Project]
    @Binding var pendingEditProjectID: UUID?
    @Binding var selection: SidebarSelection?

    @State private var searchText: String = ""
    @State private var editingConversationID: UUID? = nil
    @State private var draftTitle: String = ""
    @FocusState private var renameFocusID: UUID?

    @State private var showProjectDeleteConfirm: Bool = false
    @State private var deleteTargetProjectID: UUID? = nil

    private var visibleConversations: [Conversation] {
        viewModel.conversations.filter { !$0.isArchived }
    }

    private var flaggedConversations: [Conversation] {
        visibleConversations
            .filter { $0.flaggedAt != nil }
            .sorted { ($0.flaggedAt ?? .distantPast) > ($1.flaggedAt ?? .distantPast) }
    }

    private var unflaggedConversations: [Conversation] {
        visibleConversations
            .filter { $0.flaggedAt == nil }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var flaggedProjects: [Project] {
        projects
            .filter { $0.flaggedAt != nil }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var filteredConversations: [Conversation] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return visibleConversations }
        return visibleConversations.filter { $0.title.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // KEEP: Liquid Glass background
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 0))
                .ignoresSafeArea()

            VStack(spacing: 6) {
                // KEEP: Search field UI
                HStack(spacing: 6) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("", text: $searchText, prompt: Text("Search"))
                                .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
                .frame(height: 28)
                .padding(.horizontal, 8)
                .padding(.top, 6)

                List(selection: $selection) {
                    Section("Projects") {
                        NavigationLink(value: SidebarSelection.projects) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                Text("Projects")
                                    .padding(.horizontal, 8)
                            }
                        }
                        ForEach(flaggedProjects) { p in
                            NavigationLink(value: SidebarSelection.project(p.id)) {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder")
                                    Text(p.title)
                                        .padding(.horizontal, 8)
                                }
                            }
                            .contextMenu {
                                Button {
                                    setFlag(nil, for: p.id)
                                } label: {
                                    Label("Unflag", systemImage: "flag")
                                }
                                Button {
                                    pendingEditProjectID = p.id
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    deleteTargetProjectID = p.id
                                    showProjectDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Section("Conversations") {
                        // Flagged conversations first
                        if !flaggedConversations.isEmpty && searchText.isEmpty {
                            ForEach(flaggedConversations) { conversation in
                                conversationLink(conversation)
                            }
                        }

                        // Unflagged or filtered conversations
                        ForEach(searchText.isEmpty ? unflaggedConversations : filteredConversations) { conversation in
                            conversationLink(conversation)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden) // KEEP: Glass transparency
        }
        .alert("Delete Project?", isPresented: $showProjectDeleteConfirm) {
            Button("Cancel", role: .cancel) {
                deleteTargetProjectID = nil
            }
            Button("Delete", role: .destructive) {
                if let id = deleteTargetProjectID, let project = projects.first(where: { $0.id == id }) {
                    deleteProject(project)
                }
                deleteTargetProjectID = nil
            }
        } message: {
            if let id = deleteTargetProjectID, let project = projects.first(where: { $0.id == id }) {
                Text("Are you sure you want to delete \"\(project.title)\"? This action cannot be undone.")
            } else {
                Text("This action cannot be undone.")
            }
        }
    }

    // MARK: - Conversation Link
    @ViewBuilder
    private func conversationLink(_ conversation: Conversation) -> some View {
        NavigationLink(value: SidebarSelection.conversation(conversation.id)) {
            HStack(spacing: 6) {
                if conversation.flaggedAt != nil {
                    Image(systemName: "flag.fill")
                        .foregroundStyle((conversation.flagColor ?? .orange).color)
                        .imageScale(.small)
                }
                if editingConversationID == conversation.id {
                    TextField("Title", text: $draftTitle)
                        .textFieldStyle(.plain)
                        .onSubmit { commitRename(conversation: conversation) }
                        .onExitCommand { cancelRename() }
                        .focused($renameFocusID, equals: conversation.id)
                        .padding(.horizontal, 8)
                } else {
                    Text(conversation.title)
                        .padding(.horizontal, 8)
                }
            }
        }
        .contextMenu {
            // Flag / Unflag first (no icons)
            if conversation.flaggedAt == nil {
                Menu("Flag") {
                    ForEach(FlagColor.allCases, id: \.self) { color in
                        Button(color.accessibilityName) {
                            viewModel.flagConversation(id: conversation.id, color: color)
                        }
                    }
                }
            } else {
                Button("Unflag") {
                    viewModel.unflagConversation(id: conversation.id)
                }
            }

            // Rename
            Button("Rename") { beginRename(conversation) }

            // Archive
            Button("Archive") { archiveConversation(conversation) }

            // Separator
            Divider()

            // Delete (destructive)
            Button("Delete", role: .destructive) {
                viewModel.requestDelete(id: conversation.id)
            }
        }
    }

    // MARK: - Actions

    private func beginRename(_ conversation: Conversation) {
        editingConversationID = conversation.id
        draftTitle = conversation.title
        DispatchQueue.main.async {
            renameFocusID = conversation.id
        }
    }

    private func commitRename(conversation: Conversation) {
        let newTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTitle.isEmpty else { cancelRename(); return }

        viewModel.renameConversation(id: conversation.id, to: newTitle)
        renameFocusID = nil
        editingConversationID = nil
        draftTitle = ""
    }

    private func cancelRename() {
        renameFocusID = nil
        editingConversationID = nil
        draftTitle = ""
    }

    private func archiveConversation(_ conversation: Conversation) {
        viewModel.archiveConversation(id: conversation.id)
    }

    private func setFlag(_ color: FlagColor?, for projectID: UUID) {
        if let idx = projects.firstIndex(where: { $0.id == projectID }) {
            projects[idx].flagColor = color
            projects[idx].flaggedAt = (color == nil ? nil : Date())
        }
    }

    private func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
    }
}
