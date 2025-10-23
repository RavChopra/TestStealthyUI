//
//  ChatView.swift
//  TestStealthyUI
//
//  Chat interface - Updated to use real Conversation from ChatViewModel
//

import SwiftUI

// MARK: - Grouped Message Row
private struct GroupedMessageRow: View {
    let message: Message  // CHANGED: Use Message object instead of text/isUser
    let isGroupedWithPrevious: Bool
    let maxBubbleWidth: CGFloat

    var body: some View {
        MessageRow(
            text: message.content,  // CHANGED: Use message.content
            isUser: message.role == .user,  // CHANGED: Check message.role
            maxBubbleWidth: maxBubbleWidth
        )
        .padding(.top, isGroupedWithPrevious ? 4 : 10)
    }
}

// MARK: - Chat Messages List
private struct ChatMessagesList: View {
    let messages: [Message]  // CHANGED: Non-binding, read-only from conversation

    var body: some View {
        GeometryReader { geo in
            // Calculate proportional max widths for user (55%) and assistant (70%)
            // Subtract padding (40pt total) from available width
            let availableWidth = geo.size.width - 40
            let userMaxWidth = min(520, max(240, availableWidth * 0.55))
            let assistantMaxWidth = min(720, max(240, availableWidth * 0.70))

            ScrollViewReader { proxy in
                ScrollView {
                    // IMPORTANT: Use leading alignment for the stack.
                    // We'll control per-row alignment with Spacers inside each row HStack.
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages.indices, id: \.self) { idx in
                            let message = messages[idx]
                            let previous = idx > 0 ? messages[idx - 1] : nil
                            // CHANGED: Compare roles instead of isUser
                            let grouped = (previous?.role == message.role)

                            GroupedMessageRow(
                                message: message,  // CHANGED: Pass full message
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
                // CHANGED: Scroll when messages array changes
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

// MARK: - Chat Placeholder (for drafts)
private struct ChatPlaceholder: View {
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
                .id(currentGreetingIndex) // Force re-render on change
            Text("Type your first message below")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .onAppear {
            // Pick a random greeting on appear
            currentGreetingIndex = Int.random(in: 0..<greetings.count)
        }
    }
}

// MARK: - Chat View (Main)
struct ChatView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    let conversation: Conversation?  // Optional - nil when viewing draft

    var body: some View {
        VStack(spacing: 0) {
            // Show placeholder for draft, messages for existing conversation
            if let conversation = conversation {
                VStack(spacing: 0) {
                    if !conversation.tags.isEmpty {
                        TagsFlowView(tags: conversation.tags)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ChatMessagesList(messages: conversation.messages)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            } else if viewModel.isViewingDraft {
                // Draft mode - show placeholder
                ChatPlaceholder()
            } else {
                // No conversation selected
                Text("Select a conversation")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                TextField("Ask anything", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...12)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.secondary.opacity(0.15))
                    )
                    .onSubmit {
                        viewModel.send()
                    }

                Button(action: {
                    viewModel.send()
                }) {
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
        .navigationTitle(conversation?.title ?? (viewModel.isViewingDraft ? "New Conversation" : ""))
        .onDisappear {
            // Discard draft if navigating away without sending a message
            if viewModel.isViewingDraft {
                viewModel.discardDraftIfEmpty()
            }
        }
    }
}
