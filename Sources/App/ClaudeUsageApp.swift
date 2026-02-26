import SwiftUI

@main
struct ClaudeUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var store = AccountStore()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
                .onAppear { store.load() }
        } label: {
            Text(store.menuBarText)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}
