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
    Subtotal 52.45
    Sales Tax 4.22
    Total $56.67
    VISA **** 1234 56.67
    Change 0.00
    Suggested tip: 18% $9.80
    20% 10.89
    Thank you!
    """.components(separatedBy: "\n")

    @Test func readsItemsAndTotals() {
        let receipt = ReceiptParser.parse(lines: restaurantReceipt)

        #expect(receipt.items.map(\.name) == ["Horchata", "Carne Asada Plate", "Fish Tacos", "Guacamole & Chips"])
        // The $2.00 discount comes off the guacamole line just above it.
        #expect(receipt.items.map(\.priceCents) == [900, 1895, 1450, 1000])
        #expect(receipt.items.last?.discountCents == 200)
        #expect(receipt.items.map(\.quantity) == [2, 1, 1, 1])
        #expect(receipt.subtotalCents == 5245)
        #expect(receipt.itemsSumCents == receipt.subtotalCents)
        #expect(receipt.taxCents == 422)
        #expect(receipt.totalCents == 5667)
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

struct DiscountTests {
    private let costcoReceipt = """
    COSTCO WHOLESALE
    E 1234567 KS WATER 4.99 A
    0000345678 /1234567 1.50-
    E 7654321 ROTISSERIE CHKN 4.99
    E 1111111 BLUEBERRIES 7.49 E
    E 2222222 PAPER TOWELS 21.99 A
    TPD/1111111 2.00-
    SUBTOTAL 35.96
    TAX 2.07
    **** TOTAL 38.03
    VISA 38.03
    INSTANT SAVINGS 3.50
    """.components(separatedBy: "\n")

    @Test func costcoDiscountsComeOffTheItemTheyReference() {
        let receipt = ReceiptParser.parse(lines: costcoReceipt)

        #expect(receipt.items.map(\.name) == ["Ks Water", "Rotisserie Chkn", "Blueberries", "Paper Towels"])
        #expect(receipt.items.map(\.code) == ["1234567", "7654321", "1111111", "2222222"])
        // The blueberry discount is printed under the paper towels but
        // references the blueberries' item number, so it goes there.
        #expect(receipt.items.map(\.priceCents) == [349, 499, 549, 2199])
        #expect(receipt.items.map(\.discountCents) == [150, 0, 200, 0])
        #expect(receipt.itemsSumCents == receipt.subtotalCents)
        #expect(receipt.unappliedDiscountCents == 0)
        #expect(receipt.totalCents == 3803)
    }

    @Test func discountWithoutCodeComesOffItemAbove() {
        let receipt = ReceiptParser.parse(lines: ["Burger 10.00", "Coupon -2.50", "Fries 4.00"])
        #expect(receipt.items.map(\.priceCents) == [750, 400])
        #expect(receipt.items.first?.discountCents == 250)
    }

    @Test func discountNeverMakesAnItemNegative() {
        let receipt = ReceiptParser.parse(lines: ["Soda 1.00", "Promo 3.00-"])
        #expect(receipt.items.first?.priceCents == 0)
        #expect(receipt.unappliedDiscountCents == 200)
    }

    @Test func discountBeforeAnyItemIsReportedNotLost() {
        let receipt = ReceiptParser.parse(lines: ["Member savings -5.00", "Steak 30.00"])
        #expect(receipt.items.first?.priceCents == 3000)
        #expect(receipt.unappliedDiscountCents == 500)
    }

    @Test func stripsLeadingItemCodes() {
        #expect(ReceiptParser.stripItemCode(from: "E 1234567 KS WATER") == ("KS WATER", "1234567"))
        #expect(ReceiptParser.stripItemCode(from: "1234567 KS WATER") == ("KS WATER", "1234567"))
        #expect(ReceiptParser.stripItemCode(from: "2 Horchata").code == nil)
        #expect(ReceiptParser.stripItemCode(from: "0000345678 /1234567").code == nil)
    }
}

struct QuantityTests {
    @Test(arguments: [
        ("2 Horchata", "Horchata", 2),
        ("2x Coke", "Coke", 2),
        ("2 x Coke", "Coke", 2),
        ("Coke x2", "Coke", 2),
        ("Fish Tacos 2 @ 7.25", "Fish Tacos", 2),
        ("HORCHATA 2 @ $4.50 ea", "HORCHATA", 2),
        ("12 Wings", "Wings", 12),
        ("1 Burger", "Burger", 1),
        // Sizes and names that start with a number aren't quantities.
        ("16 oz Ribeye", "16 oz Ribeye", 1),
        ("2 Pc Chicken", "2 Pc Chicken", 1),
        ("7 Up", "7 Up", 1),
        ("1/2 Chicken", "1/2 Chicken", 1),
    ])
    func readsQuantities(_ testCase: (label: String, name: String, quantity: Int)) {
        let parsed = ReceiptParser.splitQuantity(from: testCase.label)
        #expect(parsed.name == testCase.name)
        #expect(parsed.quantity == testCase.quantity)
    }

    @Test func unitPriceLineUsesNameFromLineAbove() {
        let receipt = ReceiptParser.parse(lines: ["HORCHATA", "2 @ 4.50   9.00", "Total 9.00"])
        #expect(receipt.items.count == 1)
        #expect(receipt.items.first?.name == "Horchata")
        #expect(receipt.items.first?.quantity == 2)
        #expect(receipt.items.first?.priceCents == 900)
    }

    @Test func smallQuantitiesExpandIntoUnitsThatAddUp() {
        let item = ParsedReceipt.Item(name: "Tacos", priceCents: 1000, quantity: 3)
        let units = item.billUnits

        #expect(units.map(\.name) == ["Tacos (1 of 3)", "Tacos (2 of 3)", "Tacos (3 of 3)"])
        #expect(units.map(\.priceCents) == [334, 333, 333])
        #expect(units.reduce(0) { $0 + $1.priceCents } == 1000)
    }

    @Test func largeQuantitiesStayAsOneItem() {
        let item = ParsedReceipt.Item(name: "Wings", priceCents: 1800, quantity: 12)
        #expect(item.expandsToCount == 1)
        #expect(item.billUnits.map(\.name) == ["Wings ×12"])
        #expect(item.billUnits.first?.priceCents == 1800)
    }

    @Test func applyingAScanAddsOneBillItemPerUnit() {
        let bill = Bill()
        var receipt = ParsedReceipt()
        receipt.items = [
            .init(name: "Tacos", priceCents: 1200, quantity: 3),
            .init(name: "Guacamole", priceCents: 900),
        ]
        bill.apply(receipt, items: receipt.items)

        #expect(bill.items.count == 4)
        #expect(bill.items.reduce(0) { $0 + $1.priceCents } == 2100)
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
