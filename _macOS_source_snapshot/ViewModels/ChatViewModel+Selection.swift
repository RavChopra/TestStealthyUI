import Foundation

extension ChatViewModel {
    var selectedConversation: Conversation? {
        guard let idx = selectedIndex, conversations.indices.contains(idx) else { return nil }
        return conversations[idx]
    }
}
