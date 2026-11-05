import SwiftUI

struct ItemsSection: View {
    @Bindable var bill: Bill
    let onScan: @MainActor () -> Void
    @State private var editingItem: LineItem?

    var body: some View {
        Section {
            if bill.items.isEmpty {
                Button("Scan Receipt", systemImage: "doc.text.viewfinder", action: onScan)
                    .font(.headline)
            }

            ForEach(bill.items) { item in
                ItemRow(bill: bill, item: item) {
                    editingItem = item
                }
            }
            .onDelete { offsets in
                withAnimation { bill.removeItems(at: offsets) }
            }

            QuickAddItemRow(bill: bill)
        } header: {
            Text("Items")
        } footer: {
            if !bill.items.isEmpty && bill.people.count > 1 {
                Text("Tap names to assign. Tap more than one name to split an item.")
            }
        }
        .sheet(item: $editingItem) { item in
            EditItemSheet(bill: bill, item: item)
        }
    }
}

/// One line item with tappable name chips for fast assignment.
struct ItemRow: View {
    let bill: Bill
    let item: LineItem
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onEdit) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .foregroundStyle(.primary)
                        if let detail = splitDetail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(item.assigneeIDs.isEmpty ? .orange : .secondary)
                        }
                    }
                    Spacer()
                    Text(Money.format(item.priceCents))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !bill.people.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if bill.people.count > 1 {
                            Button {
                                bill.toggleEveryone(on: item)
                            } label: {
                                PersonChip(
                                    name: "Everyone",
                                    color: .gray,
                                    isSelected: bill.isAssignedToEveryone(item)
                                )
                            }
                            .buttonStyle(.borderless)
                        }

                        ForEach(bill.people) { person in
                            Button {
                                bill.toggle(person, on: item)
                            } label: {
                                PersonChip(
                                    name: person.name,
                                    color: PersonColor.color(for: person),
                                    isSelected: item.assigneeIDs.contains(person.id)
                                )
                            }
                            .buttonStyle(.borderless)
                            .sensoryFeedback(.selection, trigger: item.assigneeIDs.contains(person.id))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var splitDetail: String? {
        let count = item.assigneeIDs.count
        switch count {
        case 0: return bill.people.isEmpty ? nil : "Not assigned"
        case 1: return nil
        default:
            let each = Money.format(item.priceCents / count)
            return "Split \(count) ways · about \(each) each"
        }
    }
}

/// Inline entry row: type a name, type a price, hit Add. Focus jumps back to
/// the name field so a whole receipt can be keyed in quickly.
struct QuickAddItemRow: View {
    let bill: Bill

    @State private var name = ""
    @State private var priceText = ""
    @FocusState private var focusedField: Field?

    private enum Field { case name, price }

    private var priceCents: Cents? { Money.parse(priceText) }

    var body: some View {
        HStack(spacing: 12) {
            TextField("Item", text: $name)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.next)
                .focused($focusedField, equals: .name)
                .onSubmit { focusedField = .price }

            TextField("0.00", text: $priceText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 90)
                .focused($focusedField, equals: .price)

            Button("Add Item", systemImage: "plus.circle.fill", action: add)
                .labelStyle(.iconOnly)
                .font(.title2)
                .buttonStyle(.borderless)
                .disabled(priceCents == nil)
        }
        .toolbar {
            if focusedField == .price {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Add Item", action: add)
                        .fontWeight(.semibold)
                        .disabled(priceCents == nil)
                }
            }
        }
    }

    private func add() {
        guard let priceCents else { return }
        withAnimation { bill.addItem(named: name, priceCents: priceCents) }
        name = ""
        priceText = ""
        focusedField = .name
    }
}

struct EditItemSheet: View {
    let bill: Bill
    let item: LineItem

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var priceText: String

    init(bill: Bill, item: LineItem) {
        self.bill = bill
        self.item = item
        _name = State(initialValue: item.name)
        _priceText = State(initialValue: Money.editableText(item.priceCents))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Price", text: $priceText)
                    .keyboardType(.decimalPad)

                Section {
                    Button("Delete Item", role: .destructive) {
                        bill.removeItem(item)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(Money.parse(priceText) == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let cents = Money.parse(priceText),
              let index = bill.items.firstIndex(where: { $0.id == item.id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { bill.items[index].name = trimmed }
        bill.items[index].priceCents = cents
        dismiss()
    }
}
