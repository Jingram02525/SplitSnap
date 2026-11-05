import SwiftUI

/// Everyone's totals, with sharing for the whole group or one person at a time.
struct SummaryView: View {
    let bill: Bill

    var body: some View {
        let result = bill.result

        List {
            Section {
                ForEach(bill.people) { person in
                    PersonShareRow(bill: bill, person: person, share: result.share(for: person.id))
                }
            }

            if !result.isFullyAssigned {
                Section {
                    Label(
                        "\(Money.format(result.unassigned.totalCents)) isn't assigned to anyone yet.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                }
            }

            Section {
                row("Subtotal", result.subtotalCents)
                row("Tax", result.taxCents)
                row("Tip (\(bill.tipPercent)%)", result.tipCents)
                row("Bill total", result.totalCents)
                    .font(.headline)
            } footer: {
                Text("Everyone's totals add up to the bill total, to the cent.")
            }
        }
        .navigationTitle(bill.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: bill.summaryText()) {
                    Label("Share All", systemImage: "square.and.arrow.up")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ShareLink(item: bill.summaryText()) {
                Label("Send Totals to the Group", systemImage: "message.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private func row(_ label: String, _ cents: Cents) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(Money.format(cents)).monospacedDigit()
        }
    }
}

struct PersonShareRow: View {
    let bill: Bill
    let person: Person
    let share: Share
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(share.itemLines, id: \.itemID) { line in
                HStack {
                    Text(itemName(line.itemID))
                    if line.splitCount > 1 {
                        Text("÷\(line.splitCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Money.format(line.cents)).monospacedDigit()
                }
                .font(.subheadline)
            }
            detail("Tax", share.taxCents)
            detail("Tip", share.tipCents)

            ShareLink(item: bill.shareText(for: person)) {
                Label("Send \(person.name) their total", systemImage: "square.and.arrow.up")
                    .font(.subheadline)
            }
        } label: {
            HStack {
                Circle()
                    .fill(PersonColor.color(for: person))
                    .frame(width: 12, height: 12)
                Text(person.name)
                    .font(.headline)
                Spacer()
                Text(Money.format(share.totalCents))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
        }
    }

    private func itemName(_ id: UUID) -> String {
        bill.itemName(for: id)
    }

    private func detail(_ label: String, _ cents: Cents) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(Money.format(cents)).monospacedDigit()
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    NavigationStack {
        SummaryView(bill: .preview)
    }
}
