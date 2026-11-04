import Foundation

/// All money math in SplitSnap is done in integer cents so totals never drift
/// from floating-point rounding. Convert to/from `Decimal` only at the UI edge.
typealias Cents = Int

enum Money {
    /// The currency used for display. Defaults to the device locale, falling back to USD.
    static var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    /// Formats cents as a localized currency string, e.g. `1234` → `"$12.34"`.
    static func format(_ cents: Cents) -> String {
        decimal(from: cents).formatted(.currency(code: currencyCode))
    }

    static func decimal(from cents: Cents) -> Decimal {
        Decimal(cents) / 100
    }

    /// Rounds a decimal amount to the nearest cent.
    static func cents(from amount: Decimal) -> Cents {
        var value = amount * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    /// Parses user-typed text like `"12.5"`, `"$12.50"` or `"12,50"` into cents.
    /// Returns `nil` for empty or unparseable input, and for negative amounts.
    static func parse(_ text: String) -> Cents? {
        let allowed = Set("0123456789.,")
        var cleaned = String(text.filter { allowed.contains($0) })
        guard !cleaned.isEmpty else { return nil }

        // Treat the last separator as the decimal point; drop any others
        // (handles "1,234.56" and "12,50").
        if let lastSeparator = cleaned.lastIndex(where: { $0 == "." || $0 == "," }) {
            let whole = cleaned[..<lastSeparator].filter(\.isNumber)
            let fraction = cleaned[cleaned.index(after: lastSeparator)...].filter(\.isNumber)
            guard !whole.isEmpty || !fraction.isEmpty else { return nil }
            cleaned = "\(whole.isEmpty ? "0" : whole).\(fraction.isEmpty ? "0" : fraction)"
        }

        guard let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")),
              value >= 0 else { return nil }
        return cents(from: value)
    }

    /// Plain editable text for an amount, e.g. `1250` → `"12.50"`.
    static func editableText(_ cents: Cents) -> String {
        String(format: "%d.%02d", cents / 100, cents % 100)
    }
}
