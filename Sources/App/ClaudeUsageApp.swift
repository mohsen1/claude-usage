import SwiftUI

@main
struct ClaudeUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Text("Claude Usage")
                .padding()
        } label: {
            Text("—%")
        }
        .menuBarExtraStyle(.window)
    }
}
