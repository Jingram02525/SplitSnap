import SwiftUI

/// Itemized mode: tax amount, tip, and the bill totals.
struct TaxTipSection: View {
    @Bindable var bill: Bill

    var body: some View {
        let result = bill.result

        Section {
            HStack {
                Text("Tax")
                Spacer()
                CurrencyField(cents: $bill.taxCents)
                    .frame(maxWidth: 110)
            }

            TipPicker(bill: bill, tipCents: result.tipCents)

            TotalsRow(label: "Subtotal", cents: result.subtotalCents)
            TotalsRow(label: "Tax", cents: result.taxCents)
            TotalsRow(label: "Tip", cents: result.tipCents)
            TotalsRow(label: "Total", cents: result.totalCents, emphasized: true)
        } header: {
            Text("Tax & Tip")
        } footer: {
            Text("Tip is based on the pre-tax subtotal. Tax and tip are split in proportion to what each person ordered.")
        }
    }
}

/// Tip presets plus a stepper for any other percentage.
struct TipPicker: View {
    @Bindable var bill: Bill
    let tipCents: Cents

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tip")
                Spacer()
                Text("\(bill.tipPercent)% · \(Money.format(tipCents))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Picker("Tip", selection: $bill.tipPercent) {
                ForEach(Bill.tipPresets, id: \.self) { percent in
                    Text(percent == 0 ? "None" : "\(percent)%").tag(percent)
                }
                // Keeps the picker valid when a custom percentage is chosen.
                if !Bill.tipPresets.contains(bill.tipPercent) {
                    Text("\(bill.tipPercent)%").tag(bill.tipPercent)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Stepper("Custom", value: $bill.tipPercent, in: 0...100)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
            Text(Money.format(cents))
                .monospacedDigit()
        }
        .font(emphasized ? .headline : .subheadline)
        .foregroundStyle(emphasized ? .primary : .secondary)
    }
}
