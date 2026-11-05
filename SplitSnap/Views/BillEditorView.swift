import SwiftUI

/// The main screen: people → items (or a total) → tip → split.
/// Designed so a group can go from open to shared totals in under a minute.
struct BillEditorView: View {
    @Bindable var bill: Bill
    @State private var showingSummary = false
    @State private var confirmingReset = false
    @State private var scanner = ReceiptScanner()

    var body: some View {
        ScrollView {
            if bill.showsWelcome {
                WelcomeView(
                    onScan: {
                        bill.hasStarted = true
                        scanner.start()
                    },
                    onManual: start,
                    onEven: {
                        bill.mode = .even
                        start()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                VStack(spacing: 22) {
                    BillHeaderCard(bill: bill)
                    PeopleSection(bill: bill)

                    switch bill.mode {
                    case .itemized:
                        ItemsSection(bill: bill, onScan: scanner.start)
                        TaxTipSection(bill: bill)
                    case .even:
                        EvenSplitSection(bill: bill, onScan: scanner.start)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: bill.showsWelcome)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: bill.mode)
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SplitSnap")
                    .font(Theme.font(.title3, weight: .black))
                    .foregroundStyle(Theme.brandGradient)
            }
            if !bill.showsWelcome {
                ToolbarItem(placement: .topBarLeading) {
                    scanMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Bill", systemImage: "arrow.counterclockwise") {
                        confirmingReset = true
                    }
                }
            }
        }
        .confirmationDialog("Start a new bill?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Clear Everything", role: .destructive) {
                withAnimation { bill.reset() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !bill.showsWelcome {
                splitButton
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationDestination(isPresented: $showingSummary) {
            SummaryView(bill: bill)
        }
        .receiptScanning(scanner, bill: bill)
        .sensoryFeedback(.impact(weight: .medium), trigger: showingSummary) { _, isShowing in isShowing }
    }

    private func start() {
        withAnimation { bill.hasStarted = true }
    }

    private var scanMenu: some View {
        Menu {
            if scanner.cameraAvailable {
                Button("Scan with Camera", systemImage: "doc.text.viewfinder") {
                    scanner.showingCamera = true
                }
            }
            Button("Choose Photo", systemImage: "photo") {
                scanner.showingPhotoPicker = true
            }
        } label: {
            Label("Scan Receipt", systemImage: "camera.viewfinder")
        } primaryAction: {
            scanner.start()
        }
    }

    private var splitButton: some View {
        VStack(spacing: 8) {
            if let hint = readinessHint {
                Label(hint, systemImage: "sparkles")
                    .font(Theme.font(.footnote, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
            Button {
                showingSummary = true
            } label: {
                HStack {
                    Text("Split it")
                    Spacer()
                    MoneyText(cents: bill.result.totalCents, font: Theme.font(.title3, weight: .heavy))
                    Image(systemName: "arrow.right")
                        .font(.headline.weight(.heavy))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!bill.isReadyToSplit)
        }
        .animation(.snappy, value: readinessHint)
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

    private var readinessHint: String? {
        if bill.people.isEmpty { return "Add who's at the table" }
        if bill.mode == .even {
            return bill.receiptTotalCents == 0 ? "Enter or scan the receipt total" : nil
        }
        if bill.items.isEmpty { return "Add what was ordered" }
        let unassigned = bill.unassignedItemCount
        if unassigned > 0 {
            return unassigned == 1 ? "1 item still needs an owner" : "\(unassigned) items still need owners"
        }
        return nil
    }
}

/// Bill name plus the By Item / Evenly switch.
struct BillHeaderCard: View {
    @Bindable var bill: Bill

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("🍽️")
                    .font(.system(size: 26))
                TextField("What's the occasion?", text: $bill.title)
                    .font(Theme.font(.title2, weight: .heavy))
                    .submitLabel(.done)
                Image(systemName: "pencil")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            ModeSwitcher(mode: $bill.mode)
        }
        .card()
    }
}

/// A segmented control with a sliding gradient pill.
struct ModeSwitcher: View {
    @Binding var mode: SplitMode
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SplitMode.allCases) { option in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        mode = option
                    }
                } label: {
                    Label(option.title, systemImage: option.symbol)
                        .font(Theme.font(.subheadline, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(mode == option ? Color.white : Color.secondary)
                        .background {
                            if mode == option {
                                Capsule()
                                    .fill(Theme.brandGradient)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle(scale: 0.97))
            }
        }
        .padding(4)
        .background(Theme.field, in: Capsule())
        .sensoryFeedback(.selection, trigger: mode)
    }
}

#Preview("Editor") {
    NavigationStack {
        BillEditorView(bill: .preview)
    }
}

#Preview("Welcome") {
    NavigationStack {
        BillEditorView(bill: Bill())
    }
}

extension Bill {
    /// Sample data for SwiftUI previews.
    static var preview: Bill {
        let bill = Bill()
        bill.hasStarted = true
        bill.title = "La Casita"
        bill.addPerson(named: "Alex")
        bill.addPerson(named: "Sam")
        bill.addPerson(named: "Jordan")
        let ids = bill.people.map(\.id)
        bill.items = [
            LineItem(name: "Tacos al pastor", priceCents: 1450, assigneeIDs: [ids[0]]),
            LineItem(name: "Enchiladas", priceCents: 1695, assigneeIDs: [ids[1]]),
            LineItem(name: "Guacamole", priceCents: 1200, assigneeIDs: ids),
            LineItem(name: "Horchata", priceCents: 450, assigneeIDs: []),
        ]
        bill.taxCents = 372
        return bill
    }
}
