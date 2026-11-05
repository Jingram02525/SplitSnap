import Foundation

/// What we could read off a receipt. Everything is optional because OCR and
/// receipt layouts vary — the review screen lets the user confirm or fix it.
struct ParsedReceipt: Identifiable {
    struct Item: Identifiable, Hashable {
        let id = UUID()
        var name: String
        var priceCents: Cents
    }

    let id = UUID()
    var items: [Item] = []
    var subtotalCents: Cents?
    var taxCents: Cents?
    /// A gratuity / service charge already printed on the receipt.
    var tipCents: Cents?
    var totalCents: Cents?

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

            let label = priced.label
            let name = letterCount(label) >= 2 ? label : pendingName
            pendingName = nil

            guard let name, !priced.isNegative else { continue }

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
                receipt.items.append(.init(name: tidyName(name), priceCents: priced.cents))
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
