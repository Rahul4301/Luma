# Luna Browser

A fast, AI-powered browser built natively for macOS. Luna combines a SwiftUI-based browsing experience with integrated AI chat, privacy-first design, and a clean interface that feels at home on your Mac.

![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue)
![Xcode](https://img.shields.io/badge/Xcode-26.x-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![License](https://img.shields.io/badge/License-MIT-green)

> **Warning**
> Luna is in early development and **not yet ready for day-to-day use**.

---

## Features

### Browser

- Native macOS UI built entirely with SwiftUI and WebKit
- Tab management with drag-and-drop reordering and dynamic tab widths
- Theme-aware chrome that adapts to page colors
- Address bar with URL autocomplete, search suggestions, and history
- Download manager with a built-in downloads hub
- Find in page, print support, zoom controls, and keyboard shortcuts

### AI Assistant (Luna)

- Built-in AI side panel — toggle with `Cmd+E`
- Smart start page with intent classification (AI chat vs. web search)
- AI-powered command routing for browser actions (open tab, navigate, etc.)
- Per-tab chat history with conversation summarization
- Document context support (PDF, TXT, MD, JSON, CSV, XML, HTML)
- Markdown, code block, and LaTeX rendering in AI responses

### Privacy & Security

- API keys stored in the macOS Keychain
- App sandbox with minimal permissions
- No unnecessary data collection

---

## Recommended AI Provider

Luna supports multiple AI backends. For the best experience, we recommend using **[gpt-oss 120B](https://ollama.com/library/gpt-oss:120b)** via Ollama as your AI provider.

gpt-oss 120B is OpenAI's open-weight model designed for powerful reasoning, agentic tasks, and versatile developer use cases. It ships with full chain-of-thought, native function calling, and runs under a permissive Apache 2.0 license.

**Getting started with gpt-oss 120B:**

1. Install [Ollama](https://ollama.com/download) if you haven't already.
2. Pull the model:
   ```bash
   ollama run gpt-oss:120b
   ```
3. In Luna, open **Settings > AI & Models**, select **Ollama** as your provider, and choose `gpt-oss:120b` from the model list.

Luna also supports **Google Gemini** (cloud) and any other model available through your local Ollama instance.

---

## Installation

1. **Clone and set up:**

   ```bash
   git clone https://github.com/Rahul4301/Luma.git
   cd Luma
   ./scripts/setup.sh
   ```

2. **Configure code signing** (one-time):

   Open `Signing.xcconfig` (created by the setup script) and set your Apple Team ID — find yours at [Apple Developer Membership](https://developer.apple.com/account#MembershipDetailsCard):

   ```
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   ```

3. **Open and build:**

   ```bash
   open Luma.xcodeproj
   ```

   Then **Product > Run** (`Cmd+R`) in Xcode.

> **Note:** The Xcode project is generated locally via [XcodeGen](https://github.com/yonaskolb/XcodeGen) and is not checked into the repository. Always run `./scripts/setup.sh` after cloning.

### Regenerating the Xcode Project

If you modify `project.yml` or pull changes that affect the project structure:

```bash
xcodegen
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+E` | Toggle AI panel |
| `Cmd+T` | New tab |
| `Cmd+W` | Close tab |
| `Cmd+L` | Focus address bar |
| `Cmd+F` | Find in page |
| `Cmd+Y` | View history |
| `Cmd+1–9` | Switch to tab by index |
| `Cmd+Plus/Minus` | Zoom in/out |
| `Cmd+0` | Reset zoom |

---

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repo and clone your fork.
2. Create a branch: `git checkout -b feature/your-feature`
3. Run `./scripts/setup.sh` to generate the Xcode project and set up signing.
4. Make your changes, build, and test.
5. Ensure you do **not** commit `Signing.xcconfig` or any file containing your Team ID.
6. Push to your fork and open a pull request against the upstream repository.

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

You are free to use, modify, fork, and distribute this project, provided that the original copyright notice and license are included in all copies or substantial portions of the software.
