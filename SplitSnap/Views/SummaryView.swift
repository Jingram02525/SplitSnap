import SwiftUI

/// Everyone's totals, with sharing for the whole group or one person at a time.
struct SummaryView: View {
    let bill: Bill
    @State private var appeared = false
    @State private var shareTaps = 0

    var body: some View {
        let result = bill.result

        ScrollView {
            VStack(spacing: 16) {
                HeroTotalCard(bill: bill, result: result)

                if !result.isFullyAssigned {
                    Label(
                        "\(Money.format(result.unassigned.totalCents)) isn't assigned to anyone yet.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(Theme.font(.subheadline, weight: .bold))
                    .foregroundStyle(Theme.warning)
                    .card()
                }

                ForEach(Array(bill.people.enumerated()), id: \.element.id) { index, person in
                    PersonShareCard(
                        bill: bill,
                        person: person,
                        share: result.share(for: person.id),
                        billTotal: result.totalCents
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
                    .animation(
                        .spring(response: 0.55, dampingFraction: 0.75).delay(0.1 + Double(index) * 0.07),
                        value: appeared
                    )
                }

                BreakdownCard(bill: bill, result: result)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(bill.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: bill.summaryText()) {
                    Label("Share All", systemImage: "square.and.arrow.up")
                }
                .simultaneousGesture(TapGesture().onEnded { shareTaps += 1 })
            }
        }
        .safeAreaInset(edge: .bottom) {
            ShareLink(item: bill.summaryText()) {
                Label("Send Totals to the Group", systemImage: "paperplane.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .simultaneousGesture(TapGesture().onEnded { shareTaps += 1 })
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .background(
                LinearGradient(
                    colors: [Theme.background.opacity(0), Theme.background, Theme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .sensoryFeedback(.success, trigger: shareTaps)
        .onAppear { appeared = true }
    }
}

/// Gradient card with the grand total and a bar showing who pays what.
private struct HeroTotalCard: View {
    let bill: Bill
    let result: SplitResult
    @State private var countUp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(subtitle)
                    .font(Theme.font(.subheadline, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
                Spacer()
                Text("🎉")
                    .font(.title2)
            }

            MoneyText(cents: countUp ? result.totalCents : 0, font: Theme.font(size: 52))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            ShareBar(bill: bill, result: result, revealed: countUp)
                .frame(height: 14)

            Text("Includes \(Money.format(result.taxCents)) tax + \(bill.tipPercent)% tip")
                .font(Theme.font(.caption, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.8))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: Theme.cornerRadius + 4, style: .continuous))
        .shadow(color: Theme.violet.opacity(0.35), radius: 20, y: 10)
        .onAppear {
            withAnimation(.snappy(duration: 0.8).delay(0.15)) { countUp = true }
        }
    }

    private var subtitle: String {
        let count = bill.people.count
        let way = bill.mode == .even ? "evenly" : "by item"
        return count == 1 ? "1 person · \(way)" : "\(count) people · split \(way)"
    }
}

/// A capsule divided into each person's share, in their color.
private struct ShareBar: View {
    let bill: Bill
    let result: SplitResult
    let revealed: Bool

    var body: some View {
        GeometryReader { geometry in
            let total = max(result.totalCents, 1)
            let spacing: CGFloat = 3
            let available = geometry.size.width - spacing * CGFloat(max(bill.people.count - 1, 0))

            HStack(spacing: spacing) {
                ForEach(bill.people) { person in
                    let fraction = CGFloat(result.share(for: person.id).totalCents) / CGFloat(total)
                    Capsule()
                        .fill(PersonColor.color(for: person))
                        .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1))
                        .frame(width: max(revealed ? available * fraction : available / CGFloat(max(bill.people.count, 1)), 4))
                }
            }
        }
    }
}

private struct PersonShareCard: View {
    let bill: Bill
    let person: Person
    let share: Share
    let billTotal: Cents
    @State private var expanded = false

    private var color: Color { PersonColor.color(for: person) }

    private var percent: Int {
        guard billTotal > 0 else { return 0 }
        return Int((Double(share.totalCents) / Double(billTotal) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Avatar(person: person, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name)
                            .font(Theme.font(.headline, weight: .heavy))
                            .foregroundStyle(.primary)
                        Text("\(percent)% of the bill")
                            .font(Theme.font(.caption, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    MoneyText(cents: share.totalCents, font: Theme.font(size: 26))
                        .foregroundStyle(color)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.14))
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * CGFloat(percent) / 100)
                }
            }
            .frame(height: 8)

            if expanded {
                VStack(spacing: 8) {
                    ForEach(share.itemLines, id: \.itemID) { line in
                        HStack {
                            Text(bill.itemName(for: line.itemID))
                            if line.splitCount > 1 {
                                Text("÷\(line.splitCount)")
                                    .font(Theme.font(.caption, weight: .heavy))
                                    .foregroundStyle(color)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(color.opacity(0.14), in: Capsule())
                            }
                            Spacer()
                            Text(Money.format(line.cents)).monospacedDigit()
                        }
                        .font(Theme.font(.subheadline, weight: .semibold))
                    }
                    DashedDivider()
                    TotalsRow(label: "Tax", cents: share.taxCents)
                    TotalsRow(label: "Tip", cents: share.tipCents)

                    ShareLink(item: bill.shareText(for: person)) {
                        Label("Send \(person.name) their total", systemImage: "paperplane.fill")
                            .font(Theme.font(.subheadline, weight: .bold))
                            .foregroundStyle(color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(color.opacity(0.13), in: Capsule())
                    }
                    .buttonStyle(PressableStyle(scale: 0.96))
                    .padding(.top, 6)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .card()
    }
}

private struct BreakdownCard: View {
    let bill: Bill
    let result: SplitResult

    var body: some View {
        VStack(spacing: 8) {
            TotalsRow(label: "Subtotal", cents: result.subtotalCents)
            TotalsRow(label: "Tax", cents: result.taxCents)
            TotalsRow(label: "Tip (\(bill.tipPercent)%)", cents: result.tipCents)
            DashedDivider()
                .padding(.vertical, 4)
            TotalsRow(label: "Bill total", cents: result.totalCents, emphasized: true)
            Label("Everyone's totals add up to the cent.", systemImage: "checkmark.seal.fill")
                .font(Theme.font(.caption, weight: .bold))
                .foregroundStyle(Theme.success)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
        .card()
    }
}

#Preview {
    NavigationStack {
        SummaryView(bill: .preview)
    }
}
