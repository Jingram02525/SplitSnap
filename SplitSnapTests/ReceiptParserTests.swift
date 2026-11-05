import Foundation
import Testing
@testable import SplitSnap

struct ReceiptParserTests {
    private let restaurantReceipt = """
    LA CASITA MEXICAN GRILL
    123 Main St, Orange CA
    Server: Maria   Table 12
    Guests: 4
    11/04/2026 7:42 PM
    2 Horchata 9.00
    CARNE ASADA PLATE 18.95
    Fish Tacos 14.50 T
    Guacamole & Chips
    12.00
    Add cheese 0.00
    Discount -2.00
    Subtotal 54.45
    Sales Tax 4.22
    Total $58.67
    VISA **** 1234 58.67
    Change 0.00
    Suggested tip: 18% $9.80
    20% 10.89
    Thank you!
    """.components(separatedBy: "\n")

    @Test func readsItemsAndTotals() {
        let receipt = ReceiptParser.parse(lines: restaurantReceipt)

        #expect(receipt.items.map(\.name) == ["2 Horchata", "Carne Asada Plate", "Fish Tacos", "Guacamole & Chips"])
        #expect(receipt.items.map(\.priceCents) == [900, 1895, 1450, 1200])
        #expect(receipt.subtotalCents == 5445)
        #expect(receipt.taxCents == 422)
        #expect(receipt.totalCents == 5867)
        #expect(receipt.tipCents == nil) // suggestions after the total are ignored
    }

    @Test func addsUpMultipleTaxLinesAndPrintedGratuity() {
        let receipt = ReceiptParser.parse(lines: [
            "Burger 1,234.56",
            "STATE TAX 1.00",
            "LOCAL TAX: 0.50",
            "Gratuity (18%) 3.00",
            "Service Charge 2.00",
            "TOTAL DUE 10.00 USD",
        ])
        #expect(receipt.items.map(\.priceCents) == [123_456])
        #expect(receipt.taxCents == 150)
        #expect(receipt.tipCents == 500)
        #expect(receipt.totalCents == 1000)
    }

    @Test func estimatesTotalWhenNotPrinted() {
        let receipt = ReceiptParser.parse(lines: ["Pizza 20.00", "Subtotal 20.00", "Tax 1.55"])
        #expect(receipt.totalCents == nil)
        #expect(receipt.receiptTotalCents == 2155)
    }

    @Test func splitsTrailingPriceAndTaxFlag() throws {
        let parsed = try #require(ReceiptParser.splitPrice(from: "Fish Tacos 14.50 T"))
        #expect(parsed.label == "Fish Tacos")
        #expect(parsed.cents == 1450)
        #expect(!parsed.isNegative)

        #expect(ReceiptParser.splitPrice(from: "Coupon 2.00-")?.isNegative == true)
        #expect(ReceiptParser.splitPrice(from: "Table 12") == nil)
    }

    @Test func groupsFragmentsOnTheSameRow() {
        // Vision coordinates: y grows upward, so the top line has the larger midY.
        let fragments = [
            ReceiptParser.TextFragment(text: "14.50", minX: 0.80, midY: 0.700, height: 0.02),
            ReceiptParser.TextFragment(text: "Fish Tacos", minX: 0.10, midY: 0.705, height: 0.02),
            ReceiptParser.TextFragment(text: "Total", minX: 0.10, midY: 0.400, height: 0.02),
            ReceiptParser.TextFragment(text: "$16.00", minX: 0.78, midY: 0.398, height: 0.02),
        ]
        #expect(ReceiptParser.groupIntoLines(fragments) == ["Fish Tacos 14.50", "Total $16.00"])

        let receipt = ReceiptParser.parse(fragments: fragments)
        #expect(receipt.items.first?.priceCents == 1450)
        #expect(receipt.totalCents == 1600)
    }
}

struct EvenSplitTests {
    let people = [UUID(), UUID(), UUID()]

    @Test func splitsTotalEvenlyWithTipOnPreTaxAmount() {
        let result = SplitCalculator.splitEvenly(
            personIDs: people,
            receiptTotalCents: 10_800, // $100 + $8 tax
            taxCents: 800,
            tip: .percent(20)
        )
        #expect(result.tipCents == 2000)
        #expect(result.totalCents == 12_800)

        let totals = people.map { result.share(for: $0).totalCents }
        #expect(totals.reduce(0, +) == 12_800)
        #expect(totals.max()! - totals.min()! <= 1)
    }

    @Test(arguments: [1, 2, 3, 4, 7])
    func everyCentIsAccountedFor(headcount: Int) {
        let ids = (0..<headcount).map { _ in UUID() }
        let result = SplitCalculator.splitEvenly(personIDs: ids, receiptTotalCents: 5_867, taxCents: 422, tip: .percent(18))
        let shares = ids.map { result.share(for: $0) }

        #expect(shares.reduce(0) { $0 + $1.totalCents } == result.totalCents)
        #expect(shares.reduce(0) { $0 + $1.taxCents } == 422)
        #expect(shares.allSatisfy { $0.itemsCents >= 0 })
    }

    @Test func taxCannotExceedTotal() {
        let result = SplitCalculator.splitEvenly(personIDs: people, receiptTotalCents: 500, taxCents: 900, tip: .percent(0))
        #expect(result.taxCents == 500)
        #expect(result.subtotalCents == 0)
    }
}
