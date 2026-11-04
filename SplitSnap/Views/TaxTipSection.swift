import SwiftUI

struct TaxTipSection: View {
    @Bindable var bill: Bill
    @State private var taxText = ""
    @FocusState private var taxFocused: Bool

    var body: some View {
        let result = bill.result

        Section {
            HStack {
                Text("Tax")
                Spacer()
                TextField("0.00", text: $taxText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(maxWidth: 110)
                    .focused($taxFocused)
                    .onChange(of: taxText) { _, newValue in
                        bill.taxCents = Money.parse(newValue) ?? 0
                    }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Tip")
                    Spacer()
                    Text("\(bill.tipPercent)% · \(Money.format(result.tipCents))")
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

            totalsRow("Subtotal", result.subtotalCents)
            totalsRow("Tax", result.taxCents)
            totalsRow("Tip", result.tipCents)
            totalsRow("Total", result.totalCents, emphasized: true)
        } header: {
            Text("Tax & Tip")
        } footer: {
            Text("Tip is based on the pre-tax subtotal. Tax and tip are split in proportion to what each person ordered.")
        }
        .onAppear {
            if bill.taxCents > 0 && taxText.isEmpty {
                taxText = Money.editableText(bill.taxCents)
            }
        }
        .onChange(of: bill.taxCents) { _, newValue in
            // Clear the field when the bill is reset.
            if newValue == 0 && !taxFocused { taxText = "" }
        }
    }

    private func totalsRow(_ label: String, _ cents: Cents, emphasized: Bool = false) -> some View {
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
