import SwiftUI
import UIKit

extension UIApplication {
    /// Ends editing in whichever text field is active.
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Card

struct CardModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.cardStroke)
            )
            .shadow(color: Theme.shadow, radius: 16, y: 6)
    }
}

extension View {
    /// Wraps content in SplitSnap's rounded card.
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: - Section title

struct SectionTitle: View {
    let emoji: String
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text(emoji)
            Text(title)
                .font(Theme.font(.title3, weight: .heavy))
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(Theme.font(.subheadline, weight: .bold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Buttons

/// The big gradient capsule used for the main action on each screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(.headline, weight: .heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .padding(.horizontal, 20)
            .background(Capsule().fill(Theme.brandGradient))
            .shadow(color: Theme.violet.opacity(isEnabled ? 0.35 : 0), radius: 14, y: 6)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A quieter tinted capsule for secondary actions.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(.headline, weight: .bold))
            .foregroundStyle(Theme.violet)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 20)
            .background(Theme.field, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Squishes slightly on press. For chips and tappable cards.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.93

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// Round gradient "+" button.
struct AddCircleButton: View {
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: size * 0.42, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Theme.brandGradient, in: Circle())
                .shadow(color: Theme.violet.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(PressableStyle(scale: 0.88))
    }
}

// MARK: - Fields

extension View {
    /// Soft capsule background for text inputs.
    func fieldStyle() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Theme.field, in: Capsule())
    }
}

// MARK: - People

struct Avatar: View {
    let person: Person
    var size: CGFloat = 40

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(PersonColor.color(for: person).gradient, in: Circle())
    }

    private var initials: String {
        let words = person.name.split(separator: " ")
        let letters = words.prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

// MARK: - Money

/// A currency amount that rolls digits when it changes.
struct MoneyText: View {
    let cents: Cents
    var font: Font = Theme.font(.headline, weight: .bold)

    var body: some View {
        Text(Money.format(cents))
            .font(font)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(cents)))
            .animation(.snappy, value: cents)
    }
}

struct TotalsRow: View {
    let label: String
    let cents: Cents
    var emphasized = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            MoneyText(
                cents: cents,
                font: emphasized ? Theme.font(.title2, weight: .heavy) : Theme.font(.subheadline, weight: .semibold)
            )
        }
        .font(emphasized ? Theme.font(.headline, weight: .heavy) : Theme.font(.subheadline, weight: .medium))
        .foregroundStyle(emphasized ? .primary : .secondary)
    }
}

/// Receipt-style dashed divider.
struct DashedDivider: View {
    var body: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 6]))
            .foregroundStyle(.quaternary)
            .frame(height: 1.5)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

// MARK: - Layout

/// Lays chips out left to right, wrapping onto new rows as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            widest = max(widest, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
