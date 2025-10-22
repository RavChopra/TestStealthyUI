#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        // MARK: - Finder-like Split Layout
        NavigationSplitView(columnVisibility: $sidebarVisibility) {

            // MARK: Sidebar
            ConversationSidebar(viewModel: viewModel)
                // These match Finder's minimum/ideal/max behavior
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
                .toolbarBackground(.hidden, for: .windowToolbar)

        } detail: {

            // MARK: Chat Detail Area
            if let idx = viewModel.selectedIndex {
                ChatDetailView(conversation: viewModel.conversations[idx])
                    .environmentObject(viewModel)
                    .navigationTitle("local mode")
                    .navigationSubtitle(viewModel.currentModelName)
                    .toolbarBackground(.visible, for: .windowToolbar)
                    .toolbarBackground(.ultraThinMaterial, for: .windowToolbar)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack {
                    Spacer()
                    Text("Select or create a conversation to get started")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // MARK: - Sidebar Toggle Button (next to traffic lights)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.leading")
                        .symbolRenderingMode(.hierarchical)
                        .help("Toggle Sidebar")
                }
            }

            // Optional: Status breadcrumb at the top center
            ToolbarItem(placement: .status) {
                HStack(spacing: 6) {
                    Text("local mode")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(">")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text(viewModel.currentModelName)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .background(.clear)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbarBackground(.ultraThinMaterial, for: .windowToolbar)

        // MARK: - Modals, Alerts, and File Handling (same as before)
        .sheet(isPresented: $viewModel.showPairingSheet) {
            PairingSheet()
                .environmentObject(viewModel)
                .frame(minWidth: 400, minHeight: 300)
        }
        .sheet(isPresented: $viewModel.showRenameSheet) {
            RenameConversationSheet(
                title: $viewModel.renameDraft,
                onConfirm: viewModel.confirmRename,
                onCancel: viewModel.cancelRename
            )
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text(viewModel.alertMessage) }

        .alert("Delete Conversation?", isPresented: $viewModel.showDeleteConfirm) {
            Button("Delete", role: .destructive) { viewModel.confirmDelete() }
            Button("Cancel", role: .cancel) { viewModel.cancelDelete() }
        } message: {
            Text("Are you sure you want to delete this conversation? This cannot be undone.")
        }

        .fileExporter(
            isPresented: $viewModel.isExporting,
            document: viewModel.exportDocument,
            contentType: UTType.stealthyAIConversations,
            defaultFilename: "StealthyAI-conversations.json"
        ) { result in
            viewModel.handleExportResult(result)
        }

        .fileImporter(
            isPresented: $viewModel.isImporting,
            allowedContentTypes: [UTType.stealthyAIConversations, .json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.handleImport(.success(url))
                } else {
                    let error = NSError(domain: "FileImport", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No file selected."])
                    viewModel.handleImport(.failure(error))
                }
            case .failure(let error):
                viewModel.handleImport(.failure(error))
            }
        }

        .sheet(isPresented: $viewModel.showImportConfirmation) {
            VStack(spacing: 20) {
                Text("Import Conversations")
                    .font(.headline)
                Text("You are about to import \(viewModel.pendingImportDocument?.archive.conversations.count ?? 0) conversation(s).")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                HStack {
                    Button("Cancel") { viewModel.cancelImport() }
                    Spacer()
                    Button("Import") { viewModel.confirmImport() }
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal)
            }
            .padding()
            .frame(minWidth: 350, minHeight: 140)
        }
    }

    // MARK: Sidebar toggle function
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)),
            with: nil
        )
    }
}

#endif
