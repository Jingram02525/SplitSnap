import SwiftUI

/// First-launch (and fresh-bill) screen: a playful illustration and the
/// three ways to start.
struct WelcomeView: View {
    let onScan: () -> Void
    let onManual: () -> Void
    let onEven: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 28) {
            SplitReceiptIllustration(animate: appeared)
                .frame(height: 250)
                .padding(.top, 12)

            VStack(spacing: 10) {
                Text("Split the bill.\nSkip the math.")
                    .font(Theme.font(size: 36))
                    .multilineTextAlignment(.center)
                    .lineSpacing(-2)

                Text("Snap the receipt, tap who had what, and send everyone their total.")
                    .font(Theme.font(.body, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: appeared)

            VStack(spacing: 12) {
                Button(action: onScan) {
                    Label("Scan a Receipt", systemImage: "camera.viewfinder")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Enter Items Manually", action: onManual)
                    .buttonStyle(SecondaryButtonStyle())

                Button(action: onEven) {
                    Text("Just split the total evenly →")
                        .font(Theme.font(.subheadline, weight: .bold))
                        .foregroundStyle(Theme.violet)
                        .padding(.vertical, 8)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appeared)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .onAppear { appeared = true }
    }
}

/// Two halves of a receipt pulling apart, with friends' avatars bobbing above.
struct SplitReceiptIllustration: View {
    let animate: Bool
    @State private var bob = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.brandGradient)
                .opacity(0.16)
                .frame(width: 230, height: 230)
                .scaleEffect(animate ? 1 : 0.6)

            HStack(spacing: animate ? 18 : 0) {
                ReceiptHalf(lines: [0.8, 0.55, 0.7], amount: "$23.45", tint: Theme.personColors[0])
                    .rotationEffect(.degrees(animate ? -9 : 0))
                ReceiptHalf(lines: [0.6, 0.75, 0.5], amount: "$18.10", tint: Theme.personColors[1])
                    .rotationEffect(.degrees(animate ? 8 : 0))
            }
            .offset(y: 18)

            floatingEmoji("🌮", x: -112, y: -78, delay: 0)
            floatingEmoji("🍕", x: 116, y: -64, delay: 0.4)
            floatingEmoji("🥤", x: -120, y: 72, delay: 0.8)
            floatingEmoji("🍜", x: 118, y: 84, delay: 0.2)
        }
        .animation(.spring(response: 0.7, dampingFraction: 0.6), value: animate)
        .onAppear { bob = true }
    }

    private func floatingEmoji(_ emoji: String, x: CGFloat, y: CGFloat, delay: Double) -> some View {
        Text(emoji)
            .font(.system(size: 34))
            .frame(width: 58, height: 58)
            .background(Theme.card, in: Circle())
            .shadow(color: Theme.shadow, radius: 10, y: 4)
            // Pop in once…
            .scaleEffect(animate ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.2 + delay / 2), value: animate)
            // …then bob forever. Kept outside so the pop never repeats.
            .offset(x: x, y: y + (bob ? -6 : 6))
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(delay), value: bob)
    }
}

private struct ReceiptHalf: View {
    let lines: [CGFloat]
    let amount: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Capsule()
                .fill(tint.gradient)
                .frame(width: 34, height: 10)
            ForEach(lines.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.secondary.opacity(0.22))
                    .frame(width: 92 * lines[index], height: 7)
            }
            Spacer(minLength: 4)
            Text(amount)
                .font(Theme.font(.headline, weight: .heavy))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .frame(width: 120, height: 160, alignment: .topLeading)
        .background(Theme.card, in: ReceiptShape())
        .shadow(color: Theme.shadow, radius: 14, y: 8)
        .overlay(ReceiptShape().stroke(Theme.cardStroke))
    }
}

/// A rectangle with a zigzag torn bottom edge.
struct ReceiptShape: Shape {
    var teeth = 8
    var toothHeight: CGFloat = 8
    var cornerRadius: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let toothWidth = rect.width / CGFloat(teeth)

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - toothHeight))

        for index in 0..<teeth {
            let startX = rect.maxX - CGFloat(index) * toothWidth
            path.addLine(to: CGPoint(x: startX - toothWidth / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: startX - toothWidth, y: rect.maxY - toothHeight))
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    ScrollView {
        WelcomeView(onScan: {}, onManual: {}, onEven: {})
    }
    .background(Theme.background)
}
