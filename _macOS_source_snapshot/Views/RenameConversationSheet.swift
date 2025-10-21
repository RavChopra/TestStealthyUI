//
//  RenameConversationSheet.swift
//  StealthyAI-macOS
//
//  Created by Rav Chopra on 12/10/2025.
//


#if os(macOS)
import SwiftUI

struct RenameConversationSheet: View {
    @Binding var title: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Rename Conversation").font(.headline)
            TextField("Conversation Name", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit { onConfirm() }
            HStack {
                Button("Cancel") { onCancel() }.keyboardShortcut(.cancelAction)
                Button("Rename") { onConfirm() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 300)
        .onAppear { isFocused = true }
    }
}
#endif