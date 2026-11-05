import SwiftUI

/// Shows what was read off the receipt so the user can confirm it before it
/// touches the bill. Uncheck anything misread; prices can be fixed afterward.
struct ScanReviewView: View {
    let bill: Bill
    @State private var receipt: ParsedReceipt
    @State private var includedIDs: Set<UUID>
    @Environment(\.dismiss) private var dismiss

    init(bill: Bill, receipt: ParsedReceipt) {
        self.bill = bill
        _receipt = State(initialValue: receipt)
        _includedIDs = State(initialValue: Set(receipt.items.map(\.id)))
    }

    private var selectedItems: [ParsedReceipt.Item] {
        receipt.items.filter { includedIDs.contains($0.id) }
    }

    private var selectedSum: Cents {
        selectedItems.reduce(0) { $0 + $1.priceCents }
    }

    var body: some View {
        NavigationStack {
            List {
                if bill.mode == .itemized {
                    itemsSection
                }
                totalsSection
            }
            .navigationTitle("Review Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle) {
                        bill.apply(receipt, items: selectedItems)
                        dismiss()
                    }
                    .disabled(!canConfirm)
                }
            }
        }
    }

    private var confirmTitle: String {
        switch bill.mode {
        case .itemized: selectedItems.count == 1 ? "Add 1 Item" : "Add \(selectedItems.count) Items"
        case .even: "Use Total"
        }
    }

    private var canConfirm: Bool {
        switch bill.mode {
        case .itemized: !selectedItems.isEmpty
        case .even: receipt.receiptTotalCents > 0
        }
    }

    // MARK: Sections

    private var itemsSection: some View {
        Section {
            if receipt.items.isEmpty {
                Text("No items found. You can still add them by hand.")
                    .foregroundStyle(.secondary)
            }
            ForEach(receipt.items) { item in
                Button {
                    toggle(item)
                } label: {
                    HStack {
                        Image(systemName: includedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(includedIDs.contains(item.id) ? Color.accentColor : Color.secondary)
                            .font(.title3)
                        Text(item.name)
                            .foregroundStyle(includedIDs.contains(item.id) ? .primary : .secondary)
                        Spacer()
                        Text(Money.format(item.priceCents))
                            .monospacedDigit()
                            .foregroundStyle(includedIDs.contains(item.id) ? .primary : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                receipt.items.remove(atOffsets: offsets)
            }
        } header: {
            Text("Items Found")
        } footer: {
            checkFooter
        }
    }

    @ViewBuilder
    private var checkFooter: some View {
        if let subtotal = receipt.subtotalCents {
            if subtotal == selectedSum {
                Label("Items match the receipt subtotal of \(Money.format(subtotal)).", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                Label(
                    "Items add up to \(Money.format(selectedSum)), but the receipt subtotal is \(Money.format(subtotal)). Check for a missed or misread item.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
            }
        } else if !receipt.items.isEmpty {
            Text("Items add up to \(Money.format(selectedSum)). Uncheck anything that isn't an item.")
        }
    }

    private var totalsSection: some View {
        Section {
            if let subtotal = receipt.subtotalCents {
                TotalsRow(label: "Subtotal", cents: subtotal)
            }
            if let tax = receipt.taxCents {
                TotalsRow(label: "Tax", cents: tax)
            }
            if let tip = receipt.tipCents {
                TotalsRow(label: "Gratuity on receipt", cents: tip)
            }
            if let total = receipt.totalCents {
                TotalsRow(label: "Total", cents: total, emphasized: true)
            } else if bill.mode == .even {
                TotalsRow(label: "Estimated total", cents: receipt.receiptTotalCents, emphasized: true)
            }
            if receipt.subtotalCents == nil && receipt.taxCents == nil && receipt.totalCents == nil {
                Text("No totals found.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Totals Found")
        } footer: {
            if let tip = receipt.tipCents, tip > 0 {
                Text("This receipt already includes a gratuity. You may want to set the tip to None.")
            } else if bill.mode == .itemized, receipt.taxCents != nil {
                Text("The tax will be filled in for you.")
            }
        }
    }

    private func toggle(_ item: ParsedReceipt.Item) {
        if includedIDs.contains(item.id) {
            includedIDs.remove(item.id)
        } else {
            includedIDs.insert(item.id)
        }
    }
}
