# **Luma Browser**

Luma is a fast, AI-powered browser built for macOS. With native SwiftUI chrome, built-in Gemini and Ollama integration, and a privacy-first design, Luma delivers a clean, intelligent browsing experience that feels at home on your Mac.

![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue)
![Xcode](https://img.shields.io/badge/Xcode-26.x-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![License](https://img.shields.io/badge/License-MIT-green)

> **Warning**
> Luma is currently in early stages of development and **not yet ready for day-to-day use**.

## Features

### Core Browser

- Native macOS UI built with SwiftUI
- Fast, responsive browsing powered by WebKit
- Tab management with drag-and-drop reordering
- Theme-aware chrome that adapts to page colors
- Address bar with URL auto-completion and search suggestions
- Download manager with downloads hub
- Find in page, print support, and zoom controls
- Browsing history with autocomplete

### AI Integration

- Built-in AI side panel (toggle with `Cmd+E`)
- Google Gemini API support (API key stored securely in macOS Keychain)
- Local Ollama support for fully on-device AI
- Smart search on the start page
- AI-powered command routing for browser actions
- Chat history persistence per tab

### Privacy & Security

- API keys stored in macOS Keychain
- App sandbox with minimal permissions
- No unnecessary data collection
- HTTPS/TLS handled by the system

## Installation

1. Clone the repository and run setup:

```bash
git clone https://github.com/Rahul4301/Luma.git
cd Luma
./scripts/setup.sh
```

2. Set up code signing (one-time):

   - Open `Signing.xcconfig` (created by the setup script)
   - Set your Apple Team ID — get it from [Apple Developer Membership](https://developer.apple.com/account#MembershipDetailsCard):

   ```
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   ```

3. Open and build:

```bash
open Luma.xcodeproj
```

Then **Product > Run** (`Cmd+R`) in Xcode.

> **Note:** The Xcode project is generated locally via [XcodeGen](https://github.com/yonaskolb/XcodeGen) and is not checked into the repository. Always run `./scripts/setup.sh` after cloning.

## Regenerating the Xcode Project

If you modify `project.yml` or pull changes that affect the project structure:

```bash
xcodegen
```

## Contributing

Contributions are welcome!

1. Fork the repo and clone your fork.
2. Create a branch: `git checkout -b feature/your-feature`
3. Run `./scripts/setup.sh` to generate the Xcode project and set up signing.
4. Make your changes.
5. Ensure you do **not** commit `Signing.xcconfig` or any file containing your Team ID.
6. Build and test, then commit and push to your fork.
7. Open a pull request against the upstream repository.

## License

See the repository for license information.
