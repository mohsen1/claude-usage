# Claude Usage

A minimal macOS menu bar app that monitors your Claude usage across multiple accounts.

<img width="296" height="407" alt="Screenshot 2026-02-27 at 08 11 08" src="https://github.com/user-attachments/assets/fc81fca8-e54b-404f-b125-30a5acbb85fb" />


## Features

- **Menu bar percentage** — see your current session usage at a glance
- **Multi-account** — monitor up to 5+ Claude accounts simultaneously
- **Session & weekly usage** — progress bars with reset countdowns
- **One-click login** — embedded browser login with automatic session detection
- **Session renewal** — click "Session expired" to re-authenticate
- **No dock icon** — lives entirely in the menu bar




## Requirements

- macOS 14 (Sonoma) or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- Xcode Command Line Tools — `xcode-select --install`

## Build & Run

```bash
# Generate Xcode project from YAML
make generate

# Build and run (Debug)
make run

# Build release
make build

# Clean everything
make clean
```

Or manually:

```bash
xcodegen generate
xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build
```

## How It Works

1. Click the percentage in your menu bar to open the popover
2. Click **Add Account** to open the login browser
3. Log in with your **email** (Google sign-in is not supported in embedded browsers)
4. The app detects your session cookie automatically and starts polling usage
5. Click an account to set it as the primary (shown in the menu bar)
6. Right-click an account for renew/remove options

### Technical Details

- Uses `claude.ai/api/organizations/{orgId}/usage` to fetch usage data
- Authentication via session cookies extracted from an embedded `WKWebView`
- Sessions persist in the macOS Keychain across app restarts and rebuilds
- Polls every 60 seconds with concurrent fetching across accounts
- Separate `WKWebsiteDataStore` per login for session isolation
- No external dependencies — pure Swift/SwiftUI/WebKit

## Project Structure

```
├── project.yml          # XcodeGen project spec
├── Makefile             # Build commands
├── Sources/
│   ├── App/             # App entry point, AppDelegate
│   ├── Models/          # Account, UsageData, UsageBucket
│   ├── Services/        # API, Keychain, AccountStore
│   └── Views/           # PopoverView, AccountRow, LoginWebView
└── Resources/
    ├── Info.plist
    └── ClaudeUsage.entitlements
```

## License

MIT
