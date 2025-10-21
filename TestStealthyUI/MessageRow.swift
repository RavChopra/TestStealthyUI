import SwiftUI

/// A single chat message row.
/// - User messages: right-aligned bubble (UIKit-based) with text left-aligned inside.
/// - Assistant messages: plain text, left-aligned and full-width.
///
/// Uses UIKit-based MessageBubbleView for user messages to achieve MessageKit-level
/// constraint precision for bubble alignment.
struct MessageRow: View {
    let text: String
    let isUser: Bool
    /// Max width for a *user* bubble (not the row).
    let maxBubbleWidth: CGFloat

    var body: some View {
        Group {
            if isUser {
                // Use UIKit-based bubble view for precise trailing alignment
                MessageBubbleView(
                    text: text,
                    isUser: isUser,
                    maxWidth: maxBubbleWidth
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                // Assistant text spans naturally; keep it on the left
                AssistantMessageView(text: text)
            }
        }
    }
}
