#if os(macOS)
import SwiftUI

/// Displays a single conversation’s messages and the input bar.
struct ChatDetailView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    let conversation: Conversation

    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(conversation.messages) { message in
                            ChatBubbleView(message: message, maxWidth: 500)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                }
                .onChange(of: conversation.messages.count) { _, _ in
                    // Auto-scroll to bottom when a new message arrives
                    withAnimation(.easeOut(duration: 0.3)) {
                        if let last = conversation.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider().opacity(0.25)

            // Message input bar
            inputBar
        }
        // Keep the main chat area transparent; the window’s content background shows through.
        .background(Color.clear)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Bottom message input field and send button.
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Type your message...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .onSubmit(viewModel.send)

            Button(action: viewModel.send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .help("Send Message")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        // Native SwiftUI material to get subtle “glass” feel without any helper view.
        .background(.ultraThinMaterial)
    }
}

/// Individual message bubble styling (right-aligned = user, left-aligned = assistant).
struct ChatBubbleView: View {
    let message: Message
    let maxWidth: CGFloat

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 0) }

            Text(message.content)
                .padding(12)
                .frame(maxWidth: maxWidth, alignment: isUser ? .trailing : .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isUser ? Color.accentColor : Color.gray.opacity(0.25))
                )
                .foregroundColor(isUser ? .white : .primary)

            if !isUser { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .padding(.horizontal, 6)
        .transition(.opacity.combined(with: .move(edge: isUser ? .trailing : .leading)))
    }
}

/// (Kept for compatibility; currently just passes through a clear background.)
struct ChatGlassBackground: View {
    var body: some View {
        Color.clear
            .ignoresSafeArea()
    }
}
#endif
