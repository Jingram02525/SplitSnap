import Foundation
import Testing
@testable import SplitSnap

struct SplitCalculatorTests {
    let alex = UUID()
    let sam = UUID()
    let jordan = UUID()

    private func item(_ cents: Cents, _ assignees: [UUID]) -> SplitInput.Item {
        .init(id: UUID(), priceCents: cents, assigneeIDs: assignees)
    }

    private func totalOfShares(_ result: SplitResult) -> Cents {
        result.shares.values.reduce(0) { $0 + $1.totalCents } + result.unassigned.totalCents
    }

    // MARK: allocate

    @Test func allocateAlwaysSumsToTotal() {
        #expect(SplitCalculator.allocate(1000, weights: [1, 1, 1]) == [334, 333, 333])
        #expect(SplitCalculator.allocate(100, weights: [1, 2]) == [33, 67])
        #expect(SplitCalculator.allocate(0, weights: [5, 5]) == [0, 0])
        #expect(SplitCalculator.allocate(500, weights: []) == [])
    }

    @Test func allocateWithZeroWeightsSplitsEvenly() {
        #expect(SplitCalculator.allocate(10, weights: [0, 0, 0]) == [4, 3, 3])
    }

    @Test(arguments: [1, 7, 99, 1001, 123_457])
    func allocateIsExactForAwkwardTotals(total: Cents) {
        let weights = [137, 1, 4250, 0, 999]
        #expect(SplitCalculator.allocate(total, weights: weights).reduce(0, +) == total)
    }

    // MARK: split

    @Test func individualItemsWithProportionalTaxAndTip() {
        let input = SplitInput(
            personIDs: [alex, sam],
            items: [item(3000, [alex]), item(1000, [sam])],
            taxCents: 400,
            tip: .percent(20)
        )
        let result = SplitCalculator.split(input)

        #expect(result.subtotalCents == 4000)
        #expect(result.tipCents == 800)
        #expect(result.totalCents == 5200)

        let a = result.share(for: alex)
        #expect(a.itemsCents == 3000)
        #expect(a.taxCents == 300)
        #expect(a.tipCents == 600)
        #expect(a.totalCents == 3900)

        let s = result.share(for: sam)
        #expect(s.totalCents == 1300)
        #expect(result.isFullyAssigned)
    }

    @Test func sharedAppetizerSplitsEvenlyAndExactly() {
        let input = SplitInput(
            personIDs: [alex, sam, jordan],
            items: [item(1000, [alex, sam, jordan])],
            taxCents: 0,
            tip: .percent(0)
        )
        let result = SplitCalculator.split(input)
        let portions = [alex, sam, jordan].map { result.share(for: $0).itemsCents }

        #expect(portions.sorted() == [333, 333, 334])
        #expect(portions.reduce(0, +) == 1000)
        #expect(result.share(for: alex).itemLines.first?.splitCount == 3)
    }

    @Test func totalsAlwaysMatchBillToTheCent() {
        let input = SplitInput(
            personIDs: [alex, sam, jordan],
            items: [
                item(1199, [alex]),
                item(1349, [sam, jordan]),
                item(899, [alex, sam, jordan]),
                item(1, [jordan]),
            ],
            taxCents: 287,
            tip: .percent(18)
        )
        let result = SplitCalculator.split(input)
        #expect(totalOfShares(result) == result.totalCents)
    }

    @Test func unassignedItemsDoNotInflateOthersTax() {
        let input = SplitInput(
            personIDs: [alex],
            items: [item(1000, [alex]), item(1000, [])],
            taxCents: 200,
            tip: .percent(0)
        )
        let result = SplitCalculator.split(input)

        #expect(!result.isFullyAssigned)
        #expect(result.share(for: alex).taxCents == 100)
        #expect(result.unassigned.totalCents == 1100)
        #expect(totalOfShares(result) == result.totalCents)
    }

    @Test func taxWithNoItemsIsSplitAmongPeople() {
        let input = SplitInput(personIDs: [alex, sam], items: [], taxCents: 101, tip: .percent(20))
        let result = SplitCalculator.split(input)

        #expect(result.unassigned.totalCents == 0)
        #expect(result.share(for: alex).taxCents + result.share(for: sam).taxCents == 101)
    }

    @Test func unknownAndDuplicateAssigneesAreIgnored() {
        let input = SplitInput(
            personIDs: [alex, sam],
            items: [item(900, [alex, alex, UUID()])],
            taxCents: 0,
            tip: .percent(0)
        )
        let result = SplitCalculator.split(input)
        #expect(result.share(for: alex).itemsCents == 900)
        #expect(result.share(for: sam).itemsCents == 0)
    }

    @Test func fixedTipAmount() {
        let input = SplitInput(
            personIDs: [alex, sam],
            items: [item(2000, [alex]), item(2000, [sam])],
            taxCents: 0,
            tip: .amount(1001)
        )
        let result = SplitCalculator.split(input)
        #expect(result.tipCents == 1001)
        #expect(result.share(for: alex).tipCents + result.share(for: sam).tipCents == 1001)
    }

    @Test func percentTipRoundsToNearestCent() {
        // 18% of $12.34 = $2.2212 → $2.22
        #expect(SplitCalculator.tipCents(for: .percent(18), subtotal: 1234) == 222)
        // 15% of $0.99 = $0.1485 → $0.15
        #expect(SplitCalculator.tipCents(for: .percent(15), subtotal: 99) == 15)
    }
}

struct MoneyTests {
    @Test func parsesCommonInputs() {
        #expect(Money.parse("12") == 1200)
        #expect(Money.parse("12.5") == 1250)
        #expect(Money.parse("$12.50") == 1250)
        #expect(Money.parse("12,50") == 1250)
        #expect(Money.parse("1,234.56") == 123_456)
        #expect(Money.parse("0.005") == 1)
    }

    @Test func rejectsEmptyInput() {
        #expect(Money.parse("") == nil)
        #expect(Money.parse("abc") == nil)
        #expect(Money.parse(".") == nil)
    }

    @Test func editableTextRoundTrips() {
        #expect(Money.editableText(1250) == "12.50")
        #expect(Money.editableText(5) == "0.05")
        #expect(Money.parse(Money.editableText(98_765)) == 98_765)
    }
}
