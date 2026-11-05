import SwiftUI

/// Even mode: type (or scan) the receipt total, pick a tip, done.
struct EvenSplitSection: View {
    @Bindable var bill: Bill
    let onScan: @MainActor () -> Void

    var body: some View {
        let result = bill.result

        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(emoji: "🧮", title: "The total")

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Receipt total, tax included")
                        .font(Theme.font(.subheadline, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(currencySymbol)
                            .font(Theme.font(size: 34))
                            .foregroundStyle(.tertiary)
                        CurrencyField(cents: $bill.receiptTotalCents, alignment: .leading)
                            .font(Theme.font(size: 44))
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Tax")
                            .font(Theme.font(.headline, weight: .bold))
                        Text("Optional: tip skips the tax")
                            .font(Theme.font(.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    CurrencyField(cents: $bill.taxCents)
                        .font(Theme.font(.body, weight: .bold))
                        .fieldStyle()
                        .frame(width: 120)
                }

                Button(action: onScan) {
                    Label("Scan the Receipt", systemImage: "camera.viewfinder")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .card()

            SectionTitle(emoji: "💸", title: "Tip")
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 18) {
                TipPicker(bill: bill, tipCents: result.tipCents)
                DashedDivider()
                TotalsRow(label: "Total with tip", cents: result.totalCents, emphasized: true)
            }
            .card()

            if !bill.people.isEmpty && result.totalCents > 0 {
                EachPaysCard(bill: bill, result: result)
                    .padding(.top, 12)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: result.totalCents > 0)
    }

    private var currencySymbol: String {
        Locale.current.currencySymbol ?? "$"
    }
}

/// The punchline of an even split: one big number and everyone's faces.
private struct EachPaysCard: View {
    let bill: Bill
    let result: SplitResult

    var body: some View {
        VStack(spacing: 12) {
            Text("Each person pays")
                .font(Theme.font(.subheadline, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.85))

            Text(perPersonText)
                .font(Theme.font(size: 44))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: perPersonText)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            HStack(spacing: -10) {
                ForEach(bill.people.prefix(8)) { person in
                    Avatar(person: person, size: 36)
                        .overlay(Circle().stroke(.white, lineWidth: 2.5))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .shadow(color: Theme.violet.opacity(0.35), radius: 18, y: 8)
    }

    /// Shares can differ by a cent; show the range honestly when they do.
    private var perPersonText: String {
        let totals = bill.people.map { result.share(for: $0.id).totalCents }
        guard let low = totals.min(), let high = totals.max() else { return "" }
        return low == high ? Money.format(low) : "\(Money.format(low))–\(Money.format(high))"
    }
}
