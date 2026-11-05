import SwiftUI

enum PersonColor {
    static var palette: [Color] { Theme.personColors }

    static func color(for person: Person) -> Color {
        palette[person.colorIndex % palette.count]
    }
}

/// A tappable name pill. Gradient-filled with a check when selected,
/// tinted when not. Pops a little when it changes.
struct PersonChip: View {
    let name: String
    let color: Color
    var isSelected: Bool = true
    var showsCheck: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if isSelected && showsCheck {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))
                    .transition(.scale.combined(with: .opacity))
            }
            Text(name)
                .lineLimit(1)
        }
        .font(Theme.font(.subheadline, weight: .bold))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .foregroundStyle(isSelected ? Color.white : color)
        .background(
            isSelected ? AnyShapeStyle(color.gradient) : AnyShapeStyle(color.opacity(0.14)),
            in: Capsule()
        )
        .shadow(color: isSelected ? color.opacity(0.35) : .clear, radius: 6, y: 3)
        .scaleEffect(isSelected ? 1 : 0.96)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isSelected)
        .contentShape(Capsule())
    }
}

#Preview {
    HStack {
        PersonChip(name: "Alex", color: Theme.personColors[0], showsCheck: true)
        PersonChip(name: "Sam", color: Theme.personColors[1], isSelected: false)
    }
    .padding()
    .background(Theme.background)
}
