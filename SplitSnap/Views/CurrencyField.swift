import SwiftUI

/// A decimal-pad text field bound to an amount in cents. While editing, the
/// user's text is left alone; when the value changes from elsewhere (a scan,
/// a reset), the field updates to match.
struct CurrencyField: View {
    let placeholder: String
    @Binding var cents: Cents

    @State private var text = ""
    @FocusState private var isFocused: Bool

    init(_ placeholder: String = "0.00", cents: Binding<Cents>) {
        self.placeholder = placeholder
        _cents = cents
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .focused($isFocused)
            .onAppear(perform: syncFromValue)
            .onChange(of: text) { _, newValue in
                if isFocused { cents = Money.parse(newValue) ?? 0 }
            }
            .onChange(of: cents) { _, _ in
                if !isFocused { syncFromValue() }
            }
    }

    private func syncFromValue() {
        text = cents == 0 ? "" : Money.editableText(cents)
    }
}
