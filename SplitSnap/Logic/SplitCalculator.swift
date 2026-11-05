import Foundation

/// How the tip is specified.
enum Tip: Hashable {
    /// A percentage of the pre-tax subtotal, e.g. `.percent(20)`.
    case percent(Int)
    /// A fixed tip amount in cents.
    case amount(Cents)
}

/// Everything the calculator needs, with no UI types involved.
struct SplitInput {
    struct Item {
        var id: UUID
        var priceCents: Cents
        var assigneeIDs: [UUID]
    }

    var personIDs: [UUID]
    var items: [Item]
    var taxCents: Cents
    var tip: Tip
}

/// One person's (or the unassigned bucket's) portion of the bill.
struct Share: Hashable {
    struct ItemLine: Hashable {
        var itemID: UUID
        var cents: Cents
        /// How many people this item was split between.
        var splitCount: Int
    }

    var itemLines: [ItemLine] = []
    var taxCents: Cents = 0
    var tipCents: Cents = 0

    var itemsCents: Cents { itemLines.reduce(0) { $0 + $1.cents } }
    var totalCents: Cents { itemsCents + taxCents + tipCents }
}

struct SplitResult {
    var shares: [UUID: Share]
    /// Items nobody has claimed yet, plus their proportional tax and tip.
    var unassigned: Share
    var subtotalCents: Cents
    var taxCents: Cents
    var tipCents: Cents

    var totalCents: Cents { subtotalCents + taxCents + tipCents }
    var isFullyAssigned: Bool { unassigned.itemLines.isEmpty }

    func share(for personID: UUID) -> Share {
        shares[personID] ?? Share()
    }
}

enum SplitCalculator {
    /// Splits a bill so that every cent is accounted for:
    /// - Each item is divided evenly among its assignees.
    /// - Tax and tip are divided in proportion to each person's item subtotal.
    /// - Leftover cents from rounding go to whoever was closest to the next cent,
    ///   so the per-person totals always add up to the bill total exactly.
    static func split(_ input: SplitInput) -> SplitResult {
        let people = input.personIDs.uniqued()
        let knownPeople = Set(people)

        var shares = Dictionary(uniqueKeysWithValues: people.map { ($0, Share()) })
        var unassigned = Share()

        for item in input.items {
            let price = max(0, item.priceCents)
            let assignees = item.assigneeIDs.uniqued().filter { knownPeople.contains($0) }

            guard !assignees.isEmpty else {
                unassigned.itemLines.append(.init(itemID: item.id, cents: price, splitCount: 0))
                continue
            }

            let portions = allocate(price, weights: Array(repeating: 1, count: assignees.count))
            for (personID, portion) in zip(assignees, portions) {
                shares[personID]?.itemLines.append(
                    .init(itemID: item.id, cents: portion, splitCount: assignees.count)
                )
            }
        }

        let subtotal = input.items.reduce(0) { $0 + max(0, $1.priceCents) }
        let tax = max(0, input.taxCents)
        let tip = tipCents(for: input.tip, subtotal: subtotal)

        // The unassigned bucket takes part in proportional allocation so that
        // assigned people are never charged tax/tip on items they didn't order.
        var weights = people.map { shares[$0]?.itemsCents ?? 0 } + [unassigned.itemsCents]
        if weights.allSatisfy({ $0 == 0 }) && !people.isEmpty {
            // Nothing priced yet (e.g. only tax entered): split evenly among people.
            weights = people.map { _ in 1 } + [0]
        }
        let taxPortions = allocate(tax, weights: weights)
        let tipPortions = allocate(tip, weights: weights)

        for (index, personID) in people.enumerated() {
            shares[personID]?.taxCents = taxPortions[index]
            shares[personID]?.tipCents = tipPortions[index]
        }
        unassigned.taxCents = taxPortions.last ?? 0
        unassigned.tipCents = tipPortions.last ?? 0

        return SplitResult(
            shares: shares,
            unassigned: unassigned,
            subtotalCents: subtotal,
            taxCents: tax,
            tipCents: tip
        )
    }

    /// Item ID used for each person's portion in an even split.
    static let evenShareItemID = UUID(uuidString: "00000000-0000-0000-0000-00000000E5E5")!

    /// Splits a receipt total evenly. `receiptTotalCents` includes tax; passing
    /// `taxCents` lets a percentage tip be figured on the pre-tax amount.
    /// Everyone's totals differ by at most a cent and add up exactly.
    static func splitEvenly(
        personIDs: [UUID],
        receiptTotalCents: Cents,
        taxCents: Cents,
        tip: Tip
    ) -> SplitResult {
        let people = personIDs.uniqued()
        let total = max(0, receiptTotalCents)
        let tax = min(max(0, taxCents), total)
        let preTax = total - tax
        let tip = tipCents(for: tip, subtotal: preTax)

        guard !people.isEmpty else {
            var unassigned = Share(taxCents: tax, tipCents: tip)
            if preTax > 0 {
                unassigned.itemLines = [.init(itemID: evenShareItemID, cents: preTax, splitCount: 0)]
            }
            return SplitResult(shares: [:], unassigned: unassigned, subtotalCents: preTax, taxCents: tax, tipCents: tip)
        }

        let evenly = Array(repeating: 1, count: people.count)
        // Split the grand total first so per-person totals are as even as possible,
        // then carve each person's tax and tip out of their total.
        let totals = allocate(total + tip, weights: evenly)
        let taxes = allocate(tax, weights: evenly)
        let tips = allocate(tip, weights: evenly)
        var bases = zip(totals, zip(taxes, tips)).map { $0 - $1.0 - $1.1 }
        if bases.contains(where: { $0 < 0 }) {
            // Only possible with a few cents total; fall back to splitting the parts.
            bases = allocate(preTax, weights: evenly)
        }

        var shares: [UUID: Share] = [:]
        for (index, personID) in people.enumerated() {
            shares[personID] = Share(
                itemLines: [.init(itemID: evenShareItemID, cents: bases[index], splitCount: people.count)],
                taxCents: taxes[index],
                tipCents: tips[index]
            )
        }
        return SplitResult(shares: shares, unassigned: Share(), subtotalCents: preTax, taxCents: tax, tipCents: tip)
    }

    static func tipCents(for tip: Tip, subtotal: Cents) -> Cents {
        switch tip {
        case .percent(let percent):
            let exact = Decimal(subtotal) * Decimal(max(0, percent)) / 100
            return Money.cents(from: exact / 100)
        case .amount(let cents):
            return max(0, cents)
        }
    }

    /// Distributes `total` cents across `weights` proportionally using the
    /// largest-remainder method. The result always sums to exactly `total`.
    /// If every weight is zero, the total is split evenly instead.
    static func allocate(_ total: Cents, weights: [Int]) -> [Cents] {
        guard !weights.isEmpty else { return [] }
        guard total > 0 else { return Array(repeating: 0, count: weights.count) }

        var effectiveWeights = weights.map { max(0, $0) }
        var weightSum = effectiveWeights.reduce(0, +)
        if weightSum == 0 {
            // Nothing meaningful to weight by — split evenly.
            effectiveWeights = Array(repeating: 1, count: weights.count)
            weightSum = weights.count
        }

        var portions = [Cents]()
        var remainders = [(index: Int, remainder: Int)]()
        for (index, weight) in effectiveWeights.enumerated() {
            let product = total * weight
            portions.append(product / weightSum)
            remainders.append((index, product % weightSum))
        }

        var leftover = total - portions.reduce(0, +)
        // Biggest remainder first; ties go to the earlier entry for stable results.
        let order = remainders.sorted {
            $0.remainder != $1.remainder ? $0.remainder > $1.remainder : $0.index < $1.index
        }
        for entry in order where leftover > 0 {
            portions[entry.index] += 1
            leftover -= 1
        }
        return portions
    }
}

private extension Array where Element: Hashable {
    /// Removes duplicates while keeping the first occurrence's order.
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
