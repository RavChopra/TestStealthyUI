import SwiftUI

public struct ProjectEditorView: View {
    public let modeTitle: String
    public let primaryButtonTitle: String
    public let initialTitle: String
    public let initialDescription: String
    public let initialTags: [String]
    public let onCancel: () -> Void
    public let onSave: (String, String, [String]) -> Void

    @State private var title: String
    @State private var desc: String
    @State private var tags: [String]
    @State private var tagEntry: String = ""

    public init(
        modeTitle: String,
        primaryButtonTitle: String,
        initialTitle: String = "",
        initialDescription: String = "",
        initialTags: [String] = [],
        onCancel: @escaping () -> Void,
        onSave: @escaping (String, String, [String]) -> Void
    ) {
        self.modeTitle = modeTitle
        self.primaryButtonTitle = primaryButtonTitle
        self.initialTitle = initialTitle
        self.initialDescription = initialDescription
        self.initialTags = initialTags
        self.onCancel = onCancel
        self.onSave = onSave
        _title = State(initialValue: initialTitle)
        _desc = State(initialValue: initialDescription)
        _tags = State(initialValue: initialTags)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(modeTitle).font(.largeTitle).bold()

            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("What are you working on?").font(.headline)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.4))
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    TextField("Name your project", text: $title)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .frame(height: 44)
            }

            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("What are you trying to achieve?").font(.headline)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.4))
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    TextEditor(text: $desc)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                        .background(Color.clear)
                    if desc.isEmpty {
                        Text("Describe your project, goals, subject, etc...")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                    }
                }
                .frame(minHeight: 140)
            }

            // Tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags").font(.headline)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.4))
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    TextField("Enter a tag and press enter", text: $tagEntry)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .onSubmit { addCurrentTag() }
                        .disabled(tags.count >= 10)
                }
                .frame(height: 44)

                if tags.count >= 10 {
                    Text("You’ve reached the maximum of 10 tags.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !tags.isEmpty {
                    TagFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text(tag)
                                    .font(.caption)
                                    .lineLimit(1)
                                Button {
                                    removeTag(tag)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.secondary.opacity(0.15))
                            )
                        }
                    }
                    .padding(.top, 2)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                Button(primaryButtonTitle) {
                    let cleaned = tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    let limited = Array(cleaned.prefix(10))
                    let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let d = desc.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    onSave(t, d, limited)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(maxWidth: 720)
    }

    private func addCurrentTag() {
        let trimmed = tagEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !tags.contains(trimmed) else { tagEntry = ""; return }
        guard tags.count < 10 else { tagEntry = ""; return }
        tags.append(trimmed)
        tagEntry = ""
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

// MARK: - Flow Layout for Wrapping Chips
private struct TagFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + horizontalSpacing
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
