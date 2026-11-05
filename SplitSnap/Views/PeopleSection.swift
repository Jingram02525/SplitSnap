import SwiftUI

struct PeopleSection: View {
    @Bindable var bill: Bill
    @State private var newName = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(
                emoji: "👋",
                title: "Who's eating?",
                trailing: bill.people.isEmpty ? nil : "\(bill.people.count)"
            )

            VStack(alignment: .leading, spacing: 14) {
                if !bill.people.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(bill.people) { person in
                            PersonTag(person: person)
                                .contextMenu {
                                    Button("Remove \(person.name)", systemImage: "trash", role: .destructive) {
                                        withAnimation(.bouncy) { bill.removePerson(person) }
                                    }
                                }
                                .transition(.scale(scale: 0.3).combined(with: .opacity))
                        }
                    }
                }

                HStack(spacing: 10) {
                    TextField("Add a name", text: $newName)
                        .font(Theme.font(.body, weight: .semibold))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($nameFieldFocused)
                        .onSubmit(addPerson)
                        .fieldStyle()

                    AddCircleButton(action: addPerson)
                        .disabled(trimmedName.isEmpty)
                        .opacity(trimmedName.isEmpty ? 0.4 : 1)
                }

                if bill.people.count > 1 {
                    Text("Touch and hold a name to remove it.")
                        .font(Theme.font(.caption, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .card()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: bill.people.count)
    }

    private var trimmedName: String {
        newName.trimmingCharacters(in: .whitespaces)
    }

    private func addPerson() {
        guard !trimmedName.isEmpty else { return }
        withAnimation(.bouncy) { bill.addPerson(named: newName) }
        newName = ""
        // Keep the keyboard up so the whole table can be added in one go.
        nameFieldFocused = true
    }
}

/// Avatar + name, used in the people list.
private struct PersonTag: View {
    let person: Person

    var body: some View {
        HStack(spacing: 7) {
            Avatar(person: person, size: 28)
            Text(person.name)
                .font(Theme.font(.subheadline, weight: .bold))
                .lineLimit(1)
        }
        .padding(.leading, 4)
        .padding(.trailing, 14)
        .padding(.vertical, 4)
        .background(PersonColor.color(for: person).opacity(0.13), in: Capsule())
    }
}
