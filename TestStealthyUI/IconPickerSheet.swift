import SwiftUI

struct IconPickerSheet: View {
    @Binding var selectedSymbol: String?
    @Binding var selectedColor: FlagColor?
    @Binding var isPresented: Bool

    // Categorized symbol sets (validated SF Symbols)
    private let categories: [(title: String, symbols: [String])] = [
        ("People", [
            // Prefer filled where available
            "person.fill",
            "person.2.fill",
            "person.crop.circle.fill",
            // No filled variants for these; keep base
            "eye.fill",
            "eye.circle", // circle has its own fill variant but we already include eye.fill for contrast
            "eyes",
            "hand.raised.fill",
            "hand.thumbsup.fill",
            "hand.thumbsdown.fill",
            "hand.point.left.fill",
            "hand.point.right.fill",
            "hand.point.up.fill",
            "hand.point.down.fill"
        ]),
        ("Animals & Nature", [
            "leaf.fill",
            "tortoise",    // no fill
            "hare",        // no fill
            "pawprint.fill",
            "ant",         // no fill
            "ladybug"      // no fill
        ]),
        ("Food & Drink", [
            "fork.knife",                  // no fill
            "cup.and.saucer",             // no fill
            "takeoutbag.and.cup.and.straw" // no fill (as of current SF Symbols)
        ]),
        ("Activity", [
            "figure.walk", // no fill
            "figure.run",  // no fill
            "dumbbell",    // no fill
            "sportscourt", // no fill
            "trophy"       // no fill
        ]),
        ("Travel & Places", [
            "airplane",         // no direct fill
            "car.fill",
            "bus.fill",
            "tram.fill",
            "ferry.fill",
            "sailboat.fill",
            "mappin",          // no fill
            "building.2"       // may not have .fill; keep base
        ]),
        ("Objects", [
            "hammer.fill",
            "wrench.fill",
            "paintbrush.fill",
            "scissors",    // no fill
            "paperclip",   // no fill
            "book.fill",
            "bookmark.fill",
            "gearshape",   // prefer gearshape over gear; gearshape.fill exists but keep base for compatibility
            "lightbulb.fill",
            "camera.fill",
            "mic.fill"
        ]),
        ("Symbols", [
            "star.fill",
            "heart.fill",
            "bolt.fill",
            "flame.fill",
            "sun.max.fill",
            "moon.fill",
            "cloud.fill",
            "checkmark.seal.fill",
            "xmark.seal.fill"
        ])
    ]

    @ViewBuilder
    private func IconGridItem(symbol: String, isSelected: Bool) -> some View {
        Image(systemName: symbol)
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(width: 32, height: 32)
            .overlay(
                Circle().stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .contentShape(Circle())
    }

    var body: some View {
        VStack(spacing: 10) {
            // Color choices container at top
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    ForEach(FlagColor.allCases, id: \.self) { color in
                        Circle()
                            .fill(color.color)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle().stroke(Color.primary.opacity(selectedColor == color ? 0.7 : 0), lineWidth: 2)
                            )
                            .onTapGesture { selectedColor = color }
                            .help(color.accessibilityName)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
                Spacer(minLength: 0)
            }

            // Hairline separator touching edges (no container)
            Divider()
                .padding(.horizontal, -12)

            // Symbols (no search; show categories)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(categories, id: \.title) { category in
                        if !category.symbols.isEmpty {
                            // Category title with left padding
                            Text(category.title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 3)

                            // Icons in a not-full-width container
                            VStack(alignment: .leading, spacing: 8) {
                                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 8), count: 6), spacing: 8) {
                                    ForEach(category.symbols, id: \.self) { symbol in
                                        Button { selectedSymbol = symbol } label: {
                                            IconGridItem(symbol: symbol, isSelected: selectedSymbol == symbol)
                                        }
                                        .buttonStyle(.plain)
                                        .help(symbol)
                                    }
                                }
                            }
                            .padding(4)
                            .frame(maxWidth: 260, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
            }
            .padding(.horizontal, -12)

            // Hairline separator touching edges
            Divider()
                .padding(.horizontal, -12)

            // Actions - rounded squares
            HStack(spacing: 12) {
                Button("No icon") { selectedSymbol = nil }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity)

                Button("Done") { isPresented = false }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
