import SwiftUI

struct PeopleSection: View {
    @Bindable var bill: Bill
    @State private var newName = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        Section {
            if !bill.people.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(bill.people) { person in
                            PersonChip(name: person.name, color: PersonColor.color(for: person))
                                .contextMenu {
                                    Button("Remove \(person.name)", systemImage: "trash", role: .destructive) {
                                        withAnimation { bill.removePerson(person) }
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack {
                TextField("Add a name", text: $newName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($nameFieldFocused)
                    .onSubmit(addPerson)

                Button("Add", systemImage: "plus.circle.fill", action: addPerson)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("People")
        } footer: {
            if bill.people.count > 1 {
                Text("Touch and hold a name to remove it.")
            }
        }
    }

    private func addPerson() {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        withAnimation { bill.addPerson(named: newName) }
        newName = ""
        // Keep the keyboard up so the whole table can be added in one go.
        nameFieldFocused = true
    }
}
