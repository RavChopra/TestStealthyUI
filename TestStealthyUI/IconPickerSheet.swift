import SwiftUI

struct IconPickerSheet: View {
    @Binding var selectedSymbol: String?
    @Binding var selectedColor: FlagColor?
    @Binding var isPresented: Bool
    @State private var search: String = ""

    // Categorized symbol sets (validated SF Symbols)
    private let categories: [(title: String, symbols: [String])] = [
        ("People", [
            "person",
            "person.fill",
            "person.2",
            "person.2.fill",
            "person.crop.circle",
            "person.crop.circle.fill",
            "figure.standing",
            "figure.standing.dress",
            "eye",
            "eye.fill",
            "eye.circle",
            "eyes",
            "hand.raised",
            "hand.raised.fill",
            "hand.thumbsup",
            "hand.thumbsdown",
            "hand.point.left",
            "hand.point.right",
            "hand.point.up",
            "hand.point.down"
        ]),
        ("Animals & Nature", [
            "leaf",
            "leaf.fill",
            "tortoise",
            "hare",
            "pawprint",
            "pawprint.fill",
            "ant",
            "ladybug"
        ]),
        ("Food & Drink", [
            "fork.knife",
            "cup.and.saucer",
            "takeoutbag.and.cup.and.straw"
        ]),
        ("Activity", [
            "figure.walk",
            "figure.run",
            "dumbbell",
            "sportscourt",
            "trophy"
        ]),
        ("Travel & Places", [
            "airplane",
            "car",
            "bus",
            "tram",
            "ferry",
            "sailboat",
            "mappin",
            "building.2"
        ]),
        ("Objects", [
            "hammer",
            "wrench",
            "paintbrush",
            "scissors",
            "paperclip",
            "book",
            "bookmark",
            "gear",
            "lightbulb",
            "camera",
            "mic"
        ]),
        ("Symbols", [
            "star",
            "heart",
            "bolt",
            "flame",
            "sun.max",
            "moon",
            "cloud",
            "checkmark.seal",
            "xmark.seal"
        ])
    ]

    @ViewBuilder
    private func IconGridItem(symbol: String, isSelected: Bool) -> some View {
        Image(systemName: symbol)
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 22)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(width: 44, height: 44)
            .overlay(
                Circle().stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .contentShape(Circle())
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            Text("Choose Icon")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Color choices row
            HStack(spacing: 8) {
                ForEach(FlagColor.allCases, id: \.self) { color in
                    Circle()
                        .fill(color.color)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle().stroke(Color.primary.opacity(selectedColor == color ? 0.6 : 0), lineWidth: 2)
                        )
                        .onTapGesture { selectedColor = color }
                        .help(color.accessibilityName)
                }
                Spacer(minLength: 0)
            }

            // Search field
            TextField("Search symbols", text: $search)
                .textFieldStyle(.roundedBorder)

            // Symbols grid
            ScrollView {
                if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(categories, id: \.title) { category in
                            if !category.symbols.isEmpty {
                                Text(category.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 2)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 12)], spacing: 12) {
                                    ForEach(category.symbols, id: \.self) { symbol in
                                        Button { selectedSymbol = symbol } label: {
                                            IconGridItem(symbol: symbol, isSelected: selectedSymbol == symbol)
                                        }
                                        .buttonStyle(.plain)
                                        .help(symbol)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    let all = categories.flatMap { $0.symbols }
                    let filtered = all.filter { $0.localizedCaseInsensitiveContains(search) } + [search]
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 12)], spacing: 12) {
                        ForEach(Array(Set(filtered)).sorted(), id: \.self) { symbol in
                            Button { selectedSymbol = symbol } label: {
                                IconGridItem(symbol: symbol, isSelected: selectedSymbol == symbol)
                            }
                            .buttonStyle(.plain)
                            .help(symbol)
                        }
                    }
                }
            }

            // Bottom bar
            HStack {
                Button("No icon") { selectedSymbol = nil }
                Spacer()
                Button("Done") { isPresented = false }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
