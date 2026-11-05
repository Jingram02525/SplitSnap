import SwiftUI

struct ItemsSection: View {
    @Bindable var bill: Bill
    let onScan: @MainActor () -> Void
    @State private var editingItem: LineItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(
                emoji: "🧾",
                title: "What'd you order?",
                trailing: bill.items.isEmpty ? nil : Money.format(bill.items.reduce(0) { $0 + $1.priceCents })
            )

            if bill.items.isEmpty {
                ScanPromptCard(action: onScan)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            ForEach(bill.items) { item in
                ItemCard(bill: bill, item: item) {
                    editingItem = item
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.85, anchor: .bottom).combined(with: .opacity),
                    removal: .scale(scale: 0.85).combined(with: .opacity)
                ))
            }

            QuickAddItemRow(bill: bill)
                .card(padding: 12)

            if !bill.items.isEmpty && bill.people.count > 1 {
                Text("Tap names to assign. Tap more than one to split an item.")
                    .font(Theme.font(.caption, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: bill.items.count)
        .sheet(item: $editingItem) { item in
            EditItemSheet(bill: bill, item: item)
        }
    }
}

/// Big friendly "scan it" button shown before any items exist.
private struct ScanPromptCard: View {
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Scan the receipt")
                        .font(Theme.font(.headline, weight: .heavy))
                        .foregroundStyle(.primary)
                    Text("We'll read the items and tax for you.")
                        .font(Theme.font(.subheadline, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .card()
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.violet.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
            )
        }
        .buttonStyle(PressableStyle(scale: 0.97))
    }
}

/// One line item with tappable name chips for fast assignment.
struct ItemCard: View {
    let bill: Bill
    let item: LineItem
    let onEdit: () -> Void

    private var needsOwner: Bool {
        item.assigneeIDs.isEmpty && !bill.people.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onEdit) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(Theme.font(.headline, weight: .bold))
                            .foregroundStyle(.primary)
                        if let detail = splitDetail {
                            Text(detail)
                                .font(Theme.font(.caption, weight: .semibold))
                                .foregroundStyle(needsOwner ? Theme.warning : Color.secondary)
                        }
                    }
                    Spacer()
                    MoneyText(cents: item.priceCents, font: Theme.font(.headline, weight: .heavy))
                        .foregroundStyle(.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !bill.people.isEmpty {
                FlowLayout(spacing: 7) {
                    if bill.people.count > 1 {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                bill.toggleEveryone(on: item)
                            }
                        } label: {
                            PersonChip(
                                name: "Everyone",
                                color: Theme.violet,
                                isSelected: bill.isAssignedToEveryone(item),
                                showsCheck: true
                            )
                        }
                        .buttonStyle(PressableStyle())
                    }

                    ForEach(bill.people) { person in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                bill.toggle(person, on: item)
                            }
                        } label: {
                            PersonChip(
                                name: person.name,
                                color: PersonColor.color(for: person),
                                isSelected: item.assigneeIDs.contains(person.id),
                                showsCheck: true
                            )
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .sensoryFeedback(.selection, trigger: item.assigneeIDs)
            }
        }
        .card()
        .overlay {
            if needsOwner {
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.warning.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
            }
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive) {
                withAnimation(.bouncy) { bill.removeItem(item) }
            }
        }
    }

    private var splitDetail: String? {
        let count = item.assigneeIDs.count
        switch count {
        case 0: return bill.people.isEmpty ? nil : "Who had this?"
        case 1: return nil
        default: return "Split \(count) ways · about \(Money.format(item.priceCents / count)) each"
        }
    }
}

/// Inline entry row: type a name, type a price, hit +. Focus jumps back to
/// the name field so a whole receipt can be keyed in quickly.
struct QuickAddItemRow: View {
    let bill: Bill

    @State private var name = ""
    @State private var priceText = ""
    @FocusState private var focusedField: Field?

    private enum Field { case name, price }

    private var priceCents: Cents? { Money.parse(priceText) }

    var body: some View {
        HStack(spacing: 8) {
            TextField("Add an item", text: $name)
                .font(Theme.font(.body, weight: .semibold))
                .textInputAutocapitalization(.sentences)
                .submitLabel(.next)
                .focused($focusedField, equals: .name)
                .onSubmit { focusedField = .price }
                .fieldStyle()

            TextField("0.00", text: $priceText)
                .font(Theme.font(.body, weight: .bold))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .focused($focusedField, equals: .price)
                .fieldStyle()
                .frame(width: 104)

            AddCircleButton(action: add)
                .disabled(priceCents == nil)
                .opacity(priceCents == nil ? 0.4 : 1)
        }
        .toolbar {
            if focusedField == .price {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Add Item", systemImage: "plus.circle.fill", action: add)
                        .labelStyle(.titleAndIcon)
                        .fontWeight(.bold)
                        .disabled(priceCents == nil)
                }
            }
        }
    }

    private func add() {
        guard let priceCents else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            bill.addItem(named: name, priceCents: priceCents)
        }
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
            VStack(spacing: 14) {
                TextField("Name", text: $name)
                    .font(Theme.font(.title3, weight: .bold))
                    .fieldStyle()
                TextField("Price", text: $priceText)
                    .font(Theme.font(.title3, weight: .bold))
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
                    .fieldStyle()

                Spacer()

                Button("Delete Item", systemImage: "trash", role: .destructive) {
                    withAnimation(.bouncy) { bill.removeItem(item) }
                    dismiss()
                }
                .font(Theme.font(.headline, weight: .bold))
                .foregroundStyle(.red)
            }
            .padding(20)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { UIApplication.shared.dismissKeyboard() }
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.bold)
                        .disabled(Money.parse(priceText) == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(28)
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
