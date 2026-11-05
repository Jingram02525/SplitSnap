import Foundation

/// What we could read off a receipt. Everything is optional because OCR and
/// receipt layouts vary — the review screen lets the user confirm or fix it.
struct ParsedReceipt: Identifiable {
    struct Item: Identifiable, Hashable {
        let id = UUID()
        var name: String
        /// The line total as printed (all units together).
        var priceCents: Cents
        var quantity: Int = 1
        /// Discounts already taken off `priceCents`, for display.
        var discountCents: Cents = 0
        /// Store item number (e.g. Costco's), used to match discount lines.
        var code: String? = nil

        /// Lines with more units than this stay as one shared item
        /// ("12 Wings") instead of flooding the bill.
        static let maxExpandedQuantity = 8

        var displayName: String {
            quantity > 1 ? "\(name) ×\(quantity)" : name
        }

        /// How many bill items this line becomes.
        var expandsToCount: Int {
            (2...Self.maxExpandedQuantity).contains(quantity) ? quantity : 1
        }

        /// The bill items for this line: one per unit for small quantities,
        /// so each unit can be assigned to a different person. Unit prices
        /// always add back up to the printed line total.
        var billUnits: [(name: String, priceCents: Cents)] {
            guard expandsToCount > 1 else { return [(name: displayName, priceCents: priceCents)] }
            let prices = SplitCalculator.allocate(priceCents, weights: Array(repeating: 1, count: quantity))
            return prices.enumerated().map { index, cents in
                (name: "\(name) (\(index + 1) of \(quantity))", priceCents: cents)
            }
        }
    }

    let id = UUID()
    var items: [Item] = []
    var subtotalCents: Cents?
    var taxCents: Cents?
    /// A gratuity / service charge already printed on the receipt.
    var tipCents: Cents?
    var totalCents: Cents?
    /// Discounts that couldn't be matched to an item.
    var unappliedDiscountCents: Cents = 0

    var itemsSumCents: Cents { items.reduce(0) { $0 + $1.priceCents } }

    /// Best guess at the amount owed before any tip the group adds.
    var receiptTotalCents: Cents {
        if let totalCents { return totalCents }
        return (subtotalCents ?? itemsSumCents) + (taxCents ?? 0) + (tipCents ?? 0)
    }

    var isEmpty: Bool {
        items.isEmpty && subtotalCents == nil && taxCents == nil && totalCents == nil
    }
}

/// Turns recognized receipt text into items and totals. Pure Swift with no
/// Vision dependency, so it's fully unit-testable with plain strings.
enum ReceiptParser {
    /// One piece of recognized text in Vision's normalized coordinates
    /// (0...1, origin at bottom-left).
    struct TextFragment {
        var text: String
        var minX: Double
        var midY: Double
        var height: Double
    }

    // MARK: Line grouping

    /// Vision often returns an item name and its price as separate fragments.
    /// This stitches fragments that sit on the same row back into one line,
    /// left to right, top to bottom.
    static func groupIntoLines(_ fragments: [TextFragment]) -> [String] {
        let sorted = fragments
            .filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.midY > $1.midY }

        var rows: [[TextFragment]] = []
        for fragment in sorted {
            if let last = rows.last, let anchor = last.first {
                let tolerance = max(anchor.height, fragment.height) * 0.6
                if abs(anchor.midY - fragment.midY) <= tolerance {
                    rows[rows.count - 1].append(fragment)
                    continue
                }
            }
            rows.append([fragment])
        }

        return rows.map { row in
            row.sorted { $0.minX < $1.minX }
                .map { $0.text.trimmingCharacters(in: .whitespaces) }
                .joined(separator: " ")
        }
    }

    // MARK: Parsing

    static func parse(fragments: [TextFragment]) -> ParsedReceipt {
        parse(lines: groupIntoLines(fragments))
    }

    static func parse(lines: [String]) -> ParsedReceipt {
        var receipt = ParsedReceipt()
        var inTotalsSection = false
        var pendingName: String?

        for rawLine in lines {
            let line = rawLine
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            guard let priced = splitPrice(from: line) else {
                // A name with its price on the next line (a common OCR split).
                if !inTotalsSection, letterCount(line) >= 2, kind(of: line) == .item {
                    pendingName = line
                } else {
                    pendingName = nil
                }
                continue
            }

            // Discounts and coupons ("1.50-", "-2.00"): take them off the
            // item they belong to so items still add up to the subtotal.
            if priced.isNegative {
                pendingName = nil
                if !inTotalsSection {
                    applyDiscount(priced.cents, label: priced.label, to: &receipt)
                }
                continue
            }

            let coded = stripItemCode(from: priced.label)
            let parts = splitQuantity(from: coded.label)
            let name = letterCount(parts.name) >= 2 ? parts.name : pendingName
            pendingName = nil

            guard let name else { continue }

            switch kind(of: name) {
            case .subtotal:
                receipt.subtotalCents = receipt.subtotalCents ?? priced.cents
                inTotalsSection = true
            case .tax:
                receipt.taxCents = (receipt.taxCents ?? 0) + priced.cents
                inTotalsSection = true
            case .tip:
                // Printed gratuity comes before the total; tip lines after it
                // are suggestions or a blank "Tip: ____" line.
                guard receipt.totalCents == nil else { continue }
                receipt.tipCents = (receipt.tipCents ?? 0) + priced.cents
                inTotalsSection = true
            case .total:
                receipt.totalCents = receipt.totalCents ?? priced.cents
                inTotalsSection = true
            case .ignore:
                continue
            case .item:
                // Anything after the totals is payment info, tip suggestions, etc.
                guard !inTotalsSection, priced.cents > 0 else { continue }
                receipt.items.append(.init(
                    name: tidyName(name),
                    priceCents: priced.cents,
                    quantity: parts.quantity,
                    code: coded.code
                ))
            }
        }
        return receipt
    }

    // MARK: Helpers

    enum LineKind { case item, subtotal, tax, tip, total, ignore }

    static func kind(of label: String) -> LineKind {
        let text = label.lowercased()
        if text.contains("suggest") { return .ignore } // "Suggested tip: 18% $9.40"
        if matches(text, #"\bsub\s*-?\s*total"#) { return .subtotal }
        if matches(text, #"\b(tip|gratuity|service charge)"#) { return .tip }
        if text.contains("%") { return .ignore } // bare tip suggestions: "20% 10.89"
        if matches(text, #"\btax"#) { return .tax }
        if matches(text, #"\b(total|amount due|balance due)\b"#) { return .total }
        if matches(text, #"\b(visa|mastercard|amex|discover|cash|change|tendered|payment|balance)\b"#) {
            return .ignore
        }
        return .item
    }

    private static let priceRegex = try! NSRegularExpression(
        pattern: #"^(.*?)[\s:]*(-)?\$?\s*(\d{1,3}(?:,\d{3})+\.\d{2}|\d+[.,]\d{2})\s*(-)?\s*[A-Za-z*]{0,3}\s*$"#
    )

    /// Splits `"Fish Tacos 14.50 T"` into `("Fish Tacos", 1450)`.
    static func splitPrice(from line: String) -> (label: String, cents: Cents, isNegative: Bool)? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = priceRegex.firstMatch(in: line, range: range),
              let labelRange = Range(match.range(at: 1), in: line),
              let numberRange = Range(match.range(at: 3), in: line),
              let cents = Money.parse(String(line[numberRange])) else { return nil }

        let isNegative = match.range(at: 2).location != NSNotFound
            || match.range(at: 4).location != NSNotFound
        let label = String(line[labelRange])
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ".:$-")))
        return (label, cents, isNegative)
    }

    // MARK: Item codes & discounts

    /// A leading store item number, optionally after a one-letter flag:
    /// "E 1234567 KS WATER" → code "1234567", label "KS WATER".
    private static let itemCodeRegex = try! NSRegularExpression(
        pattern: #"^(?:[A-Za-z]\s+)?(\d{4,})\s+(?=.*[A-Za-z])"#
    )
    private static let digitRunRegex = try! NSRegularExpression(pattern: #"\d{4,}"#)

    static func stripItemCode(from label: String) -> (label: String, code: String?) {
        guard let match = itemCodeRegex.firstMatch(in: label, range: NSRange(label.startIndex..., in: label)),
              let whole = Range(match.range, in: label),
              let codeRange = Range(match.range(at: 1), in: label) else {
            return (label, nil)
        }
        return (String(label[whole.upperBound...]), String(label[codeRange]))
    }

    /// Takes a discount off the item it references by item number (Costco
    /// prints "/1234567"), or else off the item just above it.
    private static func applyDiscount(_ cents: Cents, label: String, to receipt: inout ParsedReceipt) {
        guard !receipt.items.isEmpty else {
            receipt.unappliedDiscountCents += cents
            return
        }

        var index = receipt.items.count - 1
        let range = NSRange(label.startIndex..., in: label)
        let referencedCodes = digitRunRegex.matches(in: label, range: range).compactMap { match in
            Range(match.range, in: label).map { String(label[$0]) }
        }
        if let matched = receipt.items.lastIndex(where: { item in
            item.code.map { referencedCodes.contains($0) } ?? false
        }) {
            index = matched
        }

        let applied = min(cents, receipt.items[index].priceCents)
        receipt.items[index].priceCents -= applied
        receipt.items[index].discountCents += applied
        receipt.unappliedDiscountCents += cents - applied
    }

    // MARK: Quantities

    /// "2 @ 4.50" or "2 @ $4.50 ea" anywhere in the label.
    private static let unitPriceRegex = try! NSRegularExpression(
        pattern: #"(?:^|\s)(\d{1,3})\s*@\s*\$?\d+[.,]\d{2}(?:\s*(?:ea|each)\b)?"#,
        options: [.caseInsensitive]
    )
    /// "2 Horchata", "2x Horchata", "2 x Horchata"
    private static let leadingQuantityRegex = try! NSRegularExpression(pattern: #"^(\d{1,3})\s*[xX]?\s+(.+)$"#)
    /// "Horchata x2", "Horchata X 2"
    private static let trailingQuantityRegex = try! NSRegularExpression(pattern: #"^(.+?)\s+[xX]\s?(\d{1,3})$"#)
    /// "16 oz Ribeye" and "2 pc Chicken" are sizes, not quantities.
    private static let measureWords: Set<String> = [
        "oz", "lb", "lbs", "pc", "pcs", "piece", "pieces", "ct", "in", "inch", "ml", "cl", "l", "g", "kg",
    ]

    /// Pulls a quantity out of an item label: `"2 Horchata"` → `("Horchata", 2)`.
    /// Labels without a quantity come back unchanged with a quantity of 1.
    static func splitQuantity(from label: String) -> (name: String, quantity: Int) {
        var name = label
        var quantity: Int?

        if let match = unitPriceRegex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
           let whole = Range(match.range, in: name),
           let quantityRange = Range(match.range(at: 1), in: name) {
            quantity = Int(name[quantityRange])
            name.removeSubrange(whole)
            name = name.trimmingCharacters(in: .whitespaces)
        } else if let groups = captureGroups(of: leadingQuantityRegex, in: name),
                  let count = Int(groups[0]),
                  isPlausibleItemName(groups[1]) {
            quantity = count
            name = groups[1]
        } else if let groups = captureGroups(of: trailingQuantityRegex, in: name),
                  let count = Int(groups[1]),
                  letterCount(groups[0]) >= 2 {
            quantity = count
            name = groups[0]
        }

        return (name, max(1, quantity ?? 1))
    }

    /// Guards against "7 Up" and "16 oz Ribeye" being read as quantities.
    private static func isPlausibleItemName(_ text: String) -> Bool {
        let firstWord = text.split(separator: " ").first
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) } ?? ""
        return letterCount(text) >= 3 && !measureWords.contains(firstWord)
    }

    private static func captureGroups(of regex: NSRegularExpression, in text: String) -> [String]? {
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        return (1..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        }
    }

    // MARK: Helpers (private)

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func letterCount(_ text: String) -> Int {
        text.filter(\.isLetter).count
    }

    /// "FISH TACOS" → "Fish Tacos"; mixed-case names are left alone.
    private static func tidyName(_ name: String) -> String {
        name == name.uppercased() ? name.capitalized : name
    }
}
