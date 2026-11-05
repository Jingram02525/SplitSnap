import SwiftUI

/// Itemized mode: tax amount, tip, and the bill totals.
struct TaxTipSection: View {
    @Bindable var bill: Bill

    var body: some View {
        let result = bill.result

        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(emoji: "💸", title: "Tax & tip")

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Tax")
                        .font(Theme.font(.headline, weight: .bold))
                    Spacer()
                    CurrencyField(cents: $bill.taxCents)
                        .font(Theme.font(.body, weight: .bold))
                        .fieldStyle()
                        .frame(width: 120)
                }

                TipPicker(bill: bill, tipCents: result.tipCents)

                DashedDivider()

                VStack(spacing: 8) {
                    TotalsRow(label: "Subtotal", cents: result.subtotalCents)
                    TotalsRow(label: "Tax", cents: result.taxCents)
                    TotalsRow(label: "Tip", cents: result.tipCents)
                }
                TotalsRow(label: "Total", cents: result.totalCents, emphasized: true)
            }
            .card()

            Text("Tip is based on the pre-tax subtotal. Tax and tip are split by what each person ordered.")
                .font(Theme.font(.caption, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }
}

/// Tip preset chips plus "Other" for any percentage.
struct TipPicker: View {
    @Bindable var bill: Bill
    let tipCents: Cents
    @State private var choosingCustom = false

    private var isCustom: Bool {
        choosingCustom || !Bill.tipPresets.contains(bill.tipPercent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tip")
                    .font(Theme.font(.headline, weight: .bold))
                Text("\(bill.tipPercent)%")
                    .font(Theme.font(.subheadline, weight: .bold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(bill.tipPercent)))
                Spacer()
                MoneyText(cents: tipCents, font: Theme.font(.headline, weight: .heavy))
            }

            HStack(spacing: 6) {
                ForEach(Bill.tipPresets, id: \.self) { percent in
                    TipChip(
                        label: percent == 0 ? "None" : "\(percent)%",
                        isSelected: !isCustom && bill.tipPercent == percent
                    ) {
                        choosingCustom = false
                        bill.tipPercent = percent
                    }
                }
                TipChip(label: "Other", isSelected: isCustom) {
                    choosingCustom = true
                }
            }

            if isCustom {
                Stepper(value: $bill.tipPercent, in: 0...100) {
                    Text("Custom tip: \(bill.tipPercent)%")
                        .font(Theme.font(.subheadline, weight: .semibold))
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isCustom)
        .animation(.snappy, value: bill.tipPercent)
        .sensoryFeedback(.selection, trigger: bill.tipPercent)
    }
}

private struct TipChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.font(.subheadline, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(
                    isSelected ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.field),
                    in: Capsule()
                )
        }
        .buttonStyle(PressableStyle(scale: 0.9))
    }
}
