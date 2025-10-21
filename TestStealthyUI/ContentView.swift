//
//  ContentView.swift
//  TestStealthyUI
//
//  Main app shell with NavigationSplitView - Projects + Conversations routing
//

import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

// MARK: - Detail Router
private struct DetailView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Binding var projects: [Project]
    @Binding var pendingEditProjectID: UUID?
    @Binding var selection: SidebarSelection?

    var body: some View {
        Group {
            if let currentSelection = selection {
                viewForSelection(currentSelection)
            } else {
                Text("Select a conversation or project")
                    .foregroundStyle(.secondary)
            }
        }
        .background(Color.clear)
    }

    private func viewForSelection(_ currentSelection: SidebarSelection) -> AnyView {
        switch currentSelection {
        case .projects:
            return AnyView(
                ProjectsView(projects: $projects, pendingEditProjectID: $pendingEditProjectID, selection: $selection)
            )
        case .project(let id):
            if let idx = projects.firstIndex(where: { $0.id == id }) {
                return AnyView(
                    ProjectDetailView(project: $projects[idx], onBack: {
                        selection = .projects
                    }, onDelete: {
                        projects.remove(at: idx)
                        selection = .projects
                    }, onEdit: { p in
                        pendingEditProjectID = p.id
                    }, onToggleFavorite: {
                        if projects[idx].flaggedAt == nil {
                            projects[idx].flaggedAt = Date()
                        } else {
                            projects[idx].flaggedAt = nil
                        }
                    })
                )
            } else {
                return AnyView(Text("Project not found"))
            }
        case .conversation(let id):
            if let conversation = viewModel.conversations.first(where: { $0.id == id }) {
                return AnyView(ChatView(conversation: conversation))
            } else {
                return AnyView(Text("Conversation not found").foregroundStyle(.secondary))
            }
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @EnvironmentObject var appStore: AppStore

    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @State private var selection: SidebarSelection? = nil
    @State private var conversationID = UUID()  // For resetting chat view

    @State private var pendingEditProjectID: UUID? = nil

    @State private var showingSidebarEdit: Bool = false
    @State private var sidebarEditDraftTitle: String = ""
    @State private var sidebarEditDraftDescription: String = ""
    @State private var sidebarEditingProjectID: UUID? = nil

    @State private var didBootstrap = false

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            SidebarView(
                projects: $appStore.projects,
                pendingEditProjectID: $pendingEditProjectID,
                selection: $selection
            )
        } detail: {
            DetailView(
                projects: $appStore.projects,
                pendingEditProjectID: $pendingEditProjectID,
                selection: $selection
            )
            .id(conversationID)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
        }
        // Sync viewModel.selectedID when conversation is selected via sidebar
        .onChange(of: selection) { oldValue, newValue in
            // Auto-delete empty conversation when navigating away
            if case .conversation(let oldID) = oldValue {
                viewModel.deleteIfEmpty(id: oldID)
            }

            if case .conversation(let id) = newValue {
                viewModel.selectedID = id
            } else {
                viewModel.selectedID = nil
            }
        }
        // Sync selection when viewModel creates a new conversation
        .onChange(of: viewModel.selectedID) { _, newValue in
            if let newValue = newValue {
                // Only update if current selection is not already this conversation
                if case .conversation(let currentID)? = selection, currentID != newValue {
                    selection = .conversation(newValue)
                } else if selection == nil || selection == .projects {
                    selection = .conversation(newValue)
                }
            }
        }
        .toolbar {
#if os(macOS)
            ToolbarItemGroup(placement: .navigation) {
                if case .project = selection {
                    // Hide global New Conversation when viewing a project
                    EmptyView()
                } else {
                    Button {
                        viewModel.createEmptyConversation()
                        if let id = viewModel.selectedID {
                            selection = .conversation(id)
                        }
                        conversationID = UUID()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .help("New Conversation")
                    .keyboardShortcut("n", modifiers: [.command])
                }
            }
#endif
        }
        .onAppear {
            if !didBootstrap {
                let id = viewModel.createEmptyConversation()
                selection = .conversation(id)
                conversationID = UUID()
                didBootstrap = true
            }
        }
        .onChange(of: pendingEditProjectID) { _, newValue in
            if let id = newValue, let idx = appStore.projects.firstIndex(where: { $0.id == id }) {
                let project = appStore.projects[idx]
                sidebarEditingProjectID = id
                sidebarEditDraftTitle = project.title
                sidebarEditDraftDescription = project.description
                showingSidebarEdit = true
                pendingEditProjectID = nil
            }
        }
        .sheet(isPresented: $showingSidebarEdit) {
            projectEditSheet
        }
        .alert("Delete Conversation?", isPresented: $viewModel.showDeleteConfirm) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelDelete()
            }
            Button("Delete", role: .destructive) {
                viewModel.confirmDelete()
            }
        } message: {
            if let targetID = viewModel.deleteTargetID,
               let conversation = viewModel.conversations.first(where: { $0.id == targetID }) {
                Text("Are you sure you want to delete \"\(conversation.title)\"? This action cannot be undone.")
            }
        }
        .sheet(isPresented: $viewModel.showImportConfirmation) {
            importConfirmationSheet
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK") { viewModel.showAlert = false }
        } message: {
            Text(viewModel.alertMessage)
        }
        .fileExporter(
            isPresented: $viewModel.isExporting,
            document: viewModel.exportDocument,
            contentType: .stealthyAIConversations,
            defaultFilename: "StealthyAI Conversations.json"
        ) { result in
            viewModel.handleExportResult(result)
        }
        .fileImporter(
            isPresented: $viewModel.isImporting,
            allowedContentTypes: [.stealthyAIConversations, .json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.handleImport(.success(url))
            } else if case .failure(let error) = result {
                viewModel.handleImport(.failure(error))
            }
        }
        #if os(macOS)
        .sheet(isPresented: $viewModel.showPairingSheet) {
            PairingSheet()
                .environmentObject(viewModel)
        }
        #endif
    }

    // MARK: - Project Edit Sheet
    private var projectEditSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Edit project").font(.largeTitle).bold()
            VStack(alignment: .leading, spacing: 8) {
                Text("What are you working on?").font(.headline)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.secondary.opacity(0.4))
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    TextField("", text: $sidebarEditDraftTitle, prompt: Text("Name your project"))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .frame(height: 44)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("What are you trying to achieve?").font(.headline)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.secondary.opacity(0.4))
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    TextEditor(text: $sidebarEditDraftDescription)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                        .background(Color.clear)
                    if sidebarEditDraftDescription.isEmpty {
                        Text("Describe your project, goals, subject, etc...")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                    }
                }
                .frame(minHeight: 140)
            }
            HStack {
                Spacer()
                Button("Cancel") { showingSidebarEdit = false }
                Button("Save changes") {
                    if let id = sidebarEditingProjectID {
                        let title = sidebarEditDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        let desc = sidebarEditDraftDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !title.isEmpty else { return }
                        appStore.updateProject(id: id, title: title, description: desc)
                    }
                    showingSidebarEdit = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(sidebarEditDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(maxWidth: 720)
    }

    // MARK: - Import Confirmation Sheet
    private var importConfirmationSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Import Conversations").font(.largeTitle).bold()

            if let document = viewModel.pendingImportDocument {
                VStack(alignment: .leading, spacing: 12) {
                    Text("This will replace all current conversations with:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(document.archive.conversations.count) conversation(s)")
                        Text("Version: \(document.archive.version)")
                    }
                    .foregroundStyle(.secondary)

                    Text("Your current conversations will be permanently lost unless you export them first.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    viewModel.cancelImport()
                }
                Button("Import") {
                    viewModel.confirmImport()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(24)
        .frame(maxWidth: 520)
    }

#if os(macOS)
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
#endif
}

#Preview {
    ContentView()
        .environmentObject(ChatViewModel())
        .environmentObject(AppStore())
}

