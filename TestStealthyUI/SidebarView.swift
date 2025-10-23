//
//  SidebarView.swift
//  TestStealthyUI
//
//  Updated to use ChatViewModel with inline rename, archive, and flagging UX
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @EnvironmentObject var appStore: AppStore
    @Binding var projects: [Project]
    @Binding var pendingEditProjectID: UUID?
    @Binding var selection: SidebarSelection?

    @State private var searchText: String = ""
    @State private var showProjectDeleteConfirm: Bool = false
    @State private var deleteTargetProjectID: UUID? = nil
    @State private var showAllPinned: Bool = false

    private var visibleConversations: [Conversation] {
        viewModel.conversations
            .filter { !$0.isArchived && !$0.isPinned }  // Exclude archived AND pinned
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
        return viewModel.conversations
            .filter { !$0.isArchived && !$0.isPinned && $0.title.localizedCaseInsensitiveContains(q) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // Combined pinned conversations from all sources
    private struct PinnedItem: Identifiable {
        let id: UUID
        let conversation: Conversation
        let projectID: UUID?  // nil for ChatViewModel conversations
        let source: Source

        enum Source {
            case chatViewModel
            case project
        }
    }

    private var allPinnedConversations: [PinnedItem] {
        var items: [PinnedItem] = []

        // Add pinned conversations from ChatViewModel
        for conversation in viewModel.pinnedConversations {
            items.append(PinnedItem(
                id: conversation.id,
                conversation: conversation,
                projectID: nil,
                source: .chatViewModel
            ))
        }

        // Add pinned conversations from projects
        for (projectID, conversation) in appStore.pinnedConversationsWithProjects {
            items.append(PinnedItem(
                id: conversation.id,
                conversation: conversation,
                projectID: projectID,
                source: .project
            ))
        }

        // Sort by pinnedAt date
        return items.sorted { ($0.conversation.pinnedAt ?? .distantPast) > ($1.conversation.pinnedAt ?? .distantPast) }
    }

    private var hasAnyPinnedConversations: Bool {
        viewModel.hasPinnedConversations || appStore.hasPinnedConversations
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
                                    .frame(width: 20, alignment: .center)
                                Text("All Projects")
                                    .padding(.horizontal, 8)
                            }
                        }
                        ForEach(flaggedProjects) { p in
                            NavigationLink(value: SidebarSelection.project(p.id)) {
                                HStack(spacing: 6) {
                                    Image(systemName: p.iconSymbol ?? "folder.fill")
                                        .foregroundStyle(p.iconColor?.color ?? .primary)
                                        .frame(width: 20, alignment: .center)
                                    Text(p.title)
                                        .padding(.horizontal, 8)
                                }
                            }
                            .contextMenu {
                                Button {
                                    setFlag(nil, for: p.id)
                                } label: {
                                    Label("Unstar", systemImage: "star")
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

                    // Pinned Conversations section (only show if there are pinned items)
                    if hasAnyPinnedConversations {
                        Section("Pinned Conversations") {
                            let pinnedItems = allPinnedConversations
                            let displayItems = showAllPinned ? pinnedItems : Array(pinnedItems.prefix(5))

                            ForEach(displayItems) { item in
                                pinnedConversationLink(item: item)
                            }

                            // Show "See more" or "See less" if there are more than 5 items
                            if pinnedItems.count > 5 {
                                Button(action: {
                                    showAllPinned.toggle()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: showAllPinned ? "chevron.up" : "chevron.down")
                                            .foregroundStyle(.secondary)
                                            .imageScale(.small)
                                            .frame(width: 20, alignment: .center)
                                        Text(showAllPinned ? "See less" : "See more (\(pinnedItems.count - 5))")
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 8)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Section("Conversations") {
                        // Show all non-pinned conversations (filtered by search if applicable)
                        ForEach(searchText.isEmpty ? visibleConversations : filteredConversations) { conversation in
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

    // MARK: - Conversation Link (for ChatViewModel conversations)
    @ViewBuilder
    private func conversationLink(_ conversation: Conversation) -> some View {
        NavigationLink(value: SidebarSelection.conversation(conversation.id)) {
            HStack(spacing: 6) {
                if let symbol = conversation.iconSymbol {
                    Image(systemName: symbol)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(conversation.iconColor?.color ?? .secondary)
                        .frame(width: 18, height: 18)
                }
                Text(conversation.title)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contextMenu {
            // Pin / Unpin first
            Button(conversation.isPinned ? "Unpin" : "Pin") {
                viewModel.togglePin(id: conversation.id)
            }

            // Edit
            Button("Edit") {
                viewModel.editingConversation = conversation
                viewModel.showConversationEditSheet = true
            }

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

    // MARK: - Pinned Conversation Link (for all pinned conversations)
    @ViewBuilder
    private func pinnedConversationLink(item: PinnedItem) -> some View {
        NavigationLink(value: SidebarSelection.conversation(item.conversation.id)) {
            HStack(spacing: 6) {
                if let symbol = item.conversation.iconSymbol {
                    Image(systemName: symbol)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(item.conversation.iconColor?.color ?? .secondary)
                        .frame(width: 18, height: 18)
                }
                Text(item.conversation.title)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contextMenu {
            // Unpin
            Button("Unpin") {
                switch item.source {
                case .chatViewModel:
                    viewModel.togglePin(id: item.conversation.id)
                case .project:
                    if let projectID = item.projectID {
                        appStore.togglePin(projectID: projectID, conversationID: item.conversation.id)
                    }
                }
            }

            // Edit
            Button("Edit") {
                switch item.source {
                case .chatViewModel:
                    viewModel.editingConversation = item.conversation
                    viewModel.showConversationEditSheet = true
                case .project:
                    if item.projectID != nil {
                        appStore.editingConversation = item.conversation
                        appStore.showConversationEditSheet = true
                    }
                }
            }

            // Archive
            Button("Archive") {
                switch item.source {
                case .chatViewModel:
                    viewModel.archiveConversation(id: item.conversation.id)
                case .project:
                    if let projectID = item.projectID {
                        appStore.archiveConversation(projectID: projectID, conversationID: item.conversation.id)
                    }
                }
            }

            // Separator
            Divider()

            // Delete (destructive)
            Button("Delete", role: .destructive) {
                switch item.source {
                case .chatViewModel:
                    viewModel.requestDelete(id: item.conversation.id)
                case .project:
                    if let projectID = item.projectID {
                        appStore.deleteConversation(projectID: projectID, conversationID: item.conversation.id)
                    }
                }
            }
        }
    }

    // MARK: - Actions

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
