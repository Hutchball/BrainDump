import SwiftUI

/// A single category binding drives both the heading and the tiles. Avoids page recenter feedback.
struct TagFilterListView: View {
    let tagIds: [Int]
    @Binding var selectedTagId: Int
    let tagManager: TagManager

    var body: some View {
        VStack {
            HStack(spacing: 4) {
                categoryButton("chevron.left", label: "Previous category", delta: -1)
                let tag = tagManager.getTag(byId: selectedTagId) ?? tagManager.getDefaultTag()
                Text(selectedTagId == 0 ? "Unsorted" : tag.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: 240)
                    .background(.regularMaterial, in: Capsule())
                    .overlay { Capsule().strokeBorder(tag.uiColor, lineWidth: 2) }
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("thought-category-heading")
                categoryButton("chevron.right", label: "Next category", delta: 1)
            }
            .padding(.top, 30)
            Spacer().allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .zIndex(3700)
    }

    private func categoryButton(_ symbol: String, label: String, delta: Int) -> some View {
        Button {
            guard !tagIds.isEmpty else { return }
            let current = tagIds.firstIndex(of: selectedTagId) ?? 0
            selectedTagId = tagIds[(current + delta + tagIds.count) % tagIds.count]
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(tagIds.count < 2)
        .accessibilityLabel(label)
    }
}
