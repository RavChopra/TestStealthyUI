//
//  TestStealthyUIApp.swift
//  TestStealthyUI
//
//  Updated to integrate ChatViewModel with autosave/autoload
//

import SwiftUI

@main
struct TestStealthyUIApp: App {
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var appStore = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(appStore)
        }
        #if os(macOS)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Conversation") {
                    viewModel.createEmptyConversation()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Divider()

                Button("Pair Device...") {
                    viewModel.openPairingSheet()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .importExport) {
                Button("Export Conversations...") {
                    viewModel.startExport()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Import Conversations...") {
                    viewModel.startImport()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }
        #endif
    }
}

// MARK: - Scene Phase Observer for Autosave
extension TestStealthyUIApp {
    @MainActor
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background, .inactive:
            viewModel.saveConversations()
        default:
            break
        }
    }
}
