import SwiftUI

/// The single main screen: people → items → tax & tip → split.
/// Designed so a group can go from open to shared totals in under a minute.
struct BillEditorView: View {
    @Bindable var bill: Bill
    @State private var showingSummary = false
    @State private var confirmingReset = false

    var body: some View {
        List {
            Section {
                TextField("Bill name", text: $bill.title)
                    .font(.headline)
            }

            PeopleSection(bill: bill)
            ItemsSection(bill: bill)
            TaxTipSection(bill: bill)
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("SplitSnap")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New Bill", systemImage: "arrow.counterclockwise") {
                    confirmingReset = true
                }
                .disabled(bill.people.isEmpty && bill.items.isEmpty)
            }
        }
        .confirmationDialog("Start a new bill?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Clear Everything", role: .destructive) { bill.reset() }
        }
        .safeAreaInset(edge: .bottom) {
            splitButton
        }
        .navigationDestination(isPresented: $showingSummary) {
            SummaryView(bill: bill)
        }
    }

    private var splitButton: some View {
        VStack(spacing: 6) {
            if let hint = readinessHint {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button {
                showingSummary = true
            } label: {
                Text("Split \(Money.format(bill.result.totalCents))")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!bill.isReadyToSplit)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var readinessHint: String? {
        if bill.people.isEmpty { return "Add who's at the table" }
        if bill.items.isEmpty { return "Add what was ordered" }
        let unassigned = bill.unassignedItemCount
        if unassigned > 0 {
            return unassigned == 1 ? "1 item still needs an owner" : "\(unassigned) items still need owners"
        }
        return nil
    }
}

#Preview {
    NavigationStack {
        BillEditorView(bill: .preview)
    }
}

extension Bill {
    /// Sample data for SwiftUI previews.
    static var preview: Bill {
        let bill = Bill()
        bill.addPerson(named: "Alex")
        bill.addPerson(named: "Sam")
        bill.addPerson(named: "Jordan")
        let ids = bill.people.map(\.id)
        bill.items = [
            LineItem(name: "Tacos al pastor", priceCents: 1450, assigneeIDs: [ids[0]]),
            LineItem(name: "Enchiladas", priceCents: 1695, assigneeIDs: [ids[1]]),
            LineItem(name: "Guacamole", priceCents: 1200, assigneeIDs: ids),
            LineItem(name: "Horchata", priceCents: 450, assigneeIDs: []),
        ]
        bill.taxCents = 372
        return bill
    }
}
