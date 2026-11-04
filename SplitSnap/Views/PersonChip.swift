import SwiftUI

enum PersonColor {
    static let palette: [Color] = [.blue, .orange, .green, .pink, .purple, .teal, .red, .indigo, .mint, .brown]

    static func color(for person: Person) -> Color {
        palette[person.colorIndex % palette.count]
    }
}

/// A tappable name pill. Filled when selected, tinted outline when not.
struct PersonChip: View {
    let name: String
    let color: Color
    var isSelected: Bool = true

    var body: some View {
        Text(name)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : color)
            .background(isSelected ? color : color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(isSelected ? 0 : 0.4)))
            .contentShape(Capsule())
            .animation(.snappy(duration: 0.15), value: isSelected)
    }
}

#Preview {
    HStack {
        PersonChip(name: "Alex", color: .blue)
        PersonChip(name: "Sam", color: .orange, isSelected: false)
    }
}
