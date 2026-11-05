import SwiftUI

/// Even mode: type (or scan) the receipt total, pick a tip, done.
struct EvenSplitSection: View {
    @Bindable var bill: Bill
    let onScan: @MainActor () -> Void

    var body: some View {
        let result = bill.result

        Section {
            HStack {
                Text("Receipt total")
                Spacer()
                CurrencyField(cents: $bill.receiptTotalCents)
                    .font(.headline)
                    .frame(maxWidth: 130)
            }

            HStack {
                Text("Tax")
                Text("optional")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                CurrencyField(cents: $bill.taxCents)
                    .frame(maxWidth: 110)
            }

            Button("Scan Receipt", systemImage: "doc.text.viewfinder", action: onScan)
        } header: {
            Text("Receipt")
        } footer: {
            Text("Enter the total printed on the receipt, tax included. Adding the tax lets the tip be figured on the pre-tax amount.")
        }

        Section {
            TipPicker(bill: bill, tipCents: result.tipCents)
            TotalsRow(label: "Total with tip", cents: result.totalCents, emphasized: true)

            if !bill.people.isEmpty && result.totalCents > 0 {
                HStack {
                    Text("Each person pays")
                    Spacer()
                    Text(perPersonText(result))
                        .monospacedDigit()
                        .fontWeight(.semibold)
                }
            }
        } header: {
            Text("Tip")
        }
    }

    /// Shares can differ by a cent; show the range honestly when they do.
    private func perPersonText(_ result: SplitResult) -> String {
        let totals = bill.people.map { result.share(for: $0.id).totalCents }
        guard let low = totals.min(), let high = totals.max() else { return "" }
        return low == high ? Money.format(low) : "\(Money.format(low))–\(Money.format(high))"
    }
}
