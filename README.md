# Luma

A macOS browser with AI (Gemini and local/Ollama), theme-aware chrome, and a focus on privacy and local control.

## Requirements

- macOS 15.0+
- Xcode 26.x (or current Xcode supporting the project’s deployment target)
- For AI: Google Gemini API key and/or a local [Ollama](https://ollama.ai) install

## Build and run

1. **Clone the repo** (or your fork):
   ```bash
   git clone https://github.com/Rahul4301/Luma.git
   cd Luma
   ```

2. **Set up your own code signing** (required; see [Signing](#signing) below) so your build uses your Apple ID and doesn’t rely on the maintainer’s team.

3. **Open the project in Xcode** and build/run:
   ```bash
   open Luma.xcodeproj
   ```
   Then **Product → Run** (⌘R).

## Signing

Code signing is required to build and run on your Mac. Use **your own** signing identity so that:

- You can build and run without access to the maintainer’s Apple Developer account.
- **Your signing configuration is not committed and does not show up in PRs.**

### One-time setup

1. **Create your local signing config** (this file is gitignored and will not be committed):
   ```bash
   cp Signing.xcconfig.example Signing.xcconfig
   ```

2. **Set your Apple Team ID** in `Signing.xcconfig`:
   - Open [Apple Developer → Membership](https://developer.apple.com/account#MembershipDetailsCard) and copy your **Team ID**.
   - Open `Signing.xcconfig` and set:
     ```
     DEVELOPMENT_TEAM = YOUR_TEAM_ID
     ```
   - Save the file.

3. **In Xcode:**
   - Select the **Luma** project in the navigator, then the **Luma** target.
   - Open **Signing & Capabilities**.
   - Ensure **Automatically manage signing** is checked and that the **Team** is your team (Xcode will use `DEVELOPMENT_TEAM` from `Signing.xcconfig`).
   - For a **personal (free) Apple ID**: if you see errors about “Associated Domains” or provisioning profiles, remove the **Associated Domains** capability for that target; personal teams don’t support it.

`Signing.xcconfig` is listed in `.gitignore`, so it stays local and will **not** appear in pull requests. Do not add it to the repo.

## Contributing

1. Fork the repo and clone your fork.
2. Create a branch: `git checkout -b feature/your-feature`.
3. Set up [signing](#signing) as above so you can build and run.
4. Make your changes. Ensure you do **not** commit:
   - `Signing.xcconfig` or any file that contains your Team ID or signing identity.
   - Changes that only add or modify `DEVELOPMENT_TEAM` (or similar) in the shared project file.
5. Build and test, then commit and push to your fork.
6. Open a pull request against the upstream repository.

By keeping signing in a local, gitignored file, the project stays buildable for everyone without exposing anyone’s team ID in the repo or in PRs.

## License

See the repository for license information.
