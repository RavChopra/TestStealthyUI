import SwiftUI
import AppKit

@main
struct StealthyAI_macOSApp: App {
    @StateObject private var chatViewModel = ChatViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(chatViewModel)
                // Save conversations when app is about to quit
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    chatViewModel.saveConversations()
                }
        }
        // Modern macOS window appearance
        .windowToolbarStyle(.unifiedCompact)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        // macOS command menu
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Conversation") {
                    chatViewModel.createConversation()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Delete Conversation") {
                    if let selectedID = chatViewModel.selectedID {
                        chatViewModel.requestDelete(id: selectedID)
                    }
                }
                .keyboardShortcut(.delete)
                .disabled(chatViewModel.selectedID == nil)

                Divider()

                Button("Install on iPhone…") {
                    chatViewModel.openPairingSheet()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Divider()

                Button("Export Conversations…") {
                    chatViewModel.startExport()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Import Conversations…") {
                    chatViewModel.startImport()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Divider()
            }
        }

        // Save when app moves to background
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                chatViewModel.saveConversations()
            }
        }
    }
}
