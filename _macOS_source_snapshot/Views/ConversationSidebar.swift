#if os(macOS)
import SwiftUI

struct ConversationSidebar: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Liquid Glass background filling the sidebar
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 0))
                .ignoresSafeArea()

            List(selection: $viewModel.selectedID) {
                Section {
                    ForEach(viewModel.conversations) { c in
                        Text(c.title.isEmpty ? "Untitled Conversation" : c.title)
                            .font(.system(size: 13))
                            .tag(c.id)
                            .contextMenu {
                                Button("Rename") { viewModel.requestRename(id: c.id) }
                                Divider()
                                Button("Delete", role: .destructive) { viewModel.requestDelete(id: c.id) }
                            }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
    }
}
#endif
