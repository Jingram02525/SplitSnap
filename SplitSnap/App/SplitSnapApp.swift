import SwiftUI

@main
struct SplitSnapApp: App {
    @State private var bill = Bill()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                BillEditorView(bill: bill)
            }
        }
    }
}
