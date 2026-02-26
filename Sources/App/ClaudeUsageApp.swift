import SwiftUI

@main
struct ClaudeUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var store: AccountStore = {
        let s = AccountStore()
        s.load()
        return s
    }()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
        } label: {
            Text(store.menuBarText)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}
