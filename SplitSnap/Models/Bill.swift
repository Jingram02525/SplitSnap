import Foundation
import Observation

struct Person: Identifiable, Hashable {
    let id: UUID
    var name: String
    /// Index into `PersonColor.palette`, assigned when the person is added.
    var colorIndex: Int

    init(id: UUID = UUID(), name: String, colorIndex: Int) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
    }
}

struct LineItem: Identifiable, Hashable {
    let id: UUID
    var name: String
    var priceCents: Cents
    var assigneeIDs: [UUID]

    init(id: UUID = UUID(), name: String, priceCents: Cents, assigneeIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.priceCents = priceCents
        self.assigneeIDs = assigneeIDs
    }
}

enum SplitMode: String, CaseIterable, Identifiable {
    /// Each person pays for what they ordered.
    case itemized
    /// Everyone pays the same share of the receipt total.
    case even

    var id: Self { self }

    var title: String {
        switch self {
        case .itemized: "By Item"
        case .even: "Evenly"
        }
    }

    var symbol: String {
        switch self {
        case .itemized: "list.bullet"
        case .even: "equal"
        }
    }
}

/// The bill currently being split. In-memory for the MVP; saved receipts and
/// group history (SwiftData) come later as part of Pro.
@Observable
final class Bill {
    static let tipPresets = [0, 15, 18, 20, 25]

    var title: String = "Dinner"
    var mode: SplitMode = .itemized
    var people: [Person] = []
    var items: [LineItem] = []
    var taxCents: Cents = 0
    /// Even mode: the total printed on the receipt, tax included.
    var receiptTotalCents: Cents = 0
    var tipPercent: Int = 20
    /// Set once the user picks a way to start from the welcome screen.
    var hasStarted = false

    private var nextColorIndex = 0

    /// Show the welcome screen for a brand-new, untouched bill.
    var showsWelcome: Bool {
        !hasStarted && people.isEmpty && items.isEmpty && receiptTotalCents == 0
    }

    // MARK: People

    func addPerson(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        people.append(Person(name: name, colorIndex: nextColorIndex))
        nextColorIndex += 1
    }

    func removePerson(_ person: Person) {
        people.removeAll { $0.id == person.id }
        for index in items.indices {
            items[index].assigneeIDs.removeAll { $0 == person.id }
        }
    }

    func person(withID id: UUID) -> Person? {
        people.first { $0.id == id }
    }

    // MARK: Items

    func addItem(named rawName: String, priceCents: Cents) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        // With a single diner there's nobody else to split with — pre-assign.
        let assignees = people.count == 1 ? [people[0].id] : []
        items.append(LineItem(
            name: name.isEmpty ? "Item \(items.count + 1)" : name,
            priceCents: priceCents,
            assigneeIDs: assignees
        ))
    }

    func removeItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    func removeItem(_ item: LineItem) {
        items.removeAll { $0.id == item.id }
    }

    func toggle(_ person: Person, on item: LineItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        if let existing = items[index].assigneeIDs.firstIndex(of: person.id) {
            items[index].assigneeIDs.remove(at: existing)
        } else {
            items[index].assigneeIDs.append(person.id)
        }
    }

    /// Assigns the item to everyone, or clears it if everyone already has it.
    func toggleEveryone(on item: LineItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let everyone = people.map(\.id)
        items[index].assigneeIDs = isAssignedToEveryone(item) ? [] : everyone
    }

    func isAssignedToEveryone(_ item: LineItem) -> Bool {
        !people.isEmpty && people.allSatisfy { item.assigneeIDs.contains($0.id) }
    }

    func reset() {
        title = "Dinner"
        people = []
        items = []
        taxCents = 0
        receiptTotalCents = 0
        tipPercent = 20
        hasStarted = false
        nextColorIndex = 0
    }

    // MARK: Scanning

    /// Applies a reviewed receipt scan to the bill for the current mode.
    func apply(_ receipt: ParsedReceipt, items selected: [ParsedReceipt.Item]) {
        switch mode {
        case .itemized:
            for item in selected {
                addItem(named: item.name, priceCents: item.priceCents)
            }
            if let tax = receipt.taxCents { taxCents = tax }
        case .even:
            receiptTotalCents = receipt.receiptTotalCents
            taxCents = receipt.taxCents ?? 0
        }
    }

    // MARK: Results

    var result: SplitResult {
        switch mode {
        case .itemized: itemizedResult
        case .even:
            SplitCalculator.splitEvenly(
                personIDs: people.map(\.id),
                receiptTotalCents: receiptTotalCents,
                taxCents: taxCents,
                tip: .percent(tipPercent)
            )
        }
    }

    private var itemizedResult: SplitResult {
        SplitCalculator.split(SplitInput(
            personIDs: people.map(\.id),
            items: items.map { .init(id: $0.id, priceCents: $0.priceCents, assigneeIDs: $0.assigneeIDs) },
            taxCents: taxCents,
            tip: .percent(tipPercent)
        ))
    }

    var unassignedItemCount: Int {
        let known = Set(people.map(\.id))
        return items.filter { item in !item.assigneeIDs.contains { known.contains($0) } }.count
    }

    var isReadyToSplit: Bool {
        guard !people.isEmpty else { return false }
        switch mode {
        case .itemized: return !items.isEmpty && unassignedItemCount == 0
        case .even: return receiptTotalCents > 0
        }
    }

    /// Display name for an item line in a share (including the even-split line).
    func itemName(for id: UUID) -> String {
        if id == SplitCalculator.evenShareItemID { return "Even share" }
        return items.first { $0.id == id }?.name ?? "Item"
    }

    // MARK: Sharing

    /// One message with everyone's totals, for the group chat.
    func summaryText() -> String {
        let result = self.result
        var lines = ["\(title) — split with SplitSnap"]
        for person in people {
            lines.append("\(person.name): \(Money.format(result.share(for: person.id).totalCents))")
        }
        lines.append("Total: \(Money.format(result.totalCents)) (incl. tax + \(tipPercent)% tip)")
        return lines.joined(separator: "\n")
    }

    /// A breakdown for one person.
    func shareText(for person: Person) -> String {
        let share = result.share(for: person.id)
        var lines = ["\(person.name), your share of \(title) is \(Money.format(share.totalCents))"]
        for line in share.itemLines {
            let name = itemName(for: line.itemID)
            let suffix = line.splitCount > 1 ? " (split \(line.splitCount) ways)" : ""
            lines.append("• \(name)\(suffix): \(Money.format(line.cents))")
        }
        lines.append("Tax: \(Money.format(share.taxCents))")
        lines.append("Tip: \(Money.format(share.tipCents))")
        return lines.joined(separator: "\n")
    }
}
