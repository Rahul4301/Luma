# Xcode Signing & Capabilities vs Code Fixes

## What you can control in Xcode

### Signing & Capabilities → App Sandbox

Under **Signing & Capabilities** for the Luma target, **App Sandbox** adds entitlements that control what the app can access. These are already set in `Luma.entitlements`:

| Entitlement | Purpose |
|-------------|--------|
| **App Sandbox** (`com.apple.security.app-sandbox`) | Enables sandbox. Required for distribution. |
| **Downloads Folder** (`com.apple.security.files.downloads.read-write`) | Read/write ~/Downloads (saving downloads, our download manager). |
| **User Selected File** (`com.apple.security.files.user-selected.read-write`) | Read/write files the user picks (file upload from Downloads, Save As). |
| **Network (Client)** (`com.apple.security.network.client`) | Outbound HTTP/HTTPS (loading web pages). |

You can enable/disable these in Xcode: select the target → **Signing & Capabilities** → **App Sandbox** → check the boxes for **Downloads**, **User Selected File**, **Outgoing Connections (Client)**. The entitlements file is updated automatically when you change those checkboxes.

### Frameworks, Libraries, and Embedded Content

This section is for **linked frameworks** (e.g. WebKit.framework, SwiftUI.framework). It does **not** control:

- File viewing (file:// in the browser)
- Upload/download behavior
- Zoom or tab reordering

Those are implemented in app code. Adding or removing frameworks here does not fix “can’t view files” or “can’t upload”; the right entitlements (above) and the right code (e.g. `loadFileURL`, handling file://) do.

---

## What had to be fixed in code (not in Capabilities)

| Feature | Why it’s code, not Capabilities |
|--------|----------------------------------|
| **View local files (PDF, Word, etc.) in tabs** | WKWebView must use `loadFileURL(_:allowingReadAccessTo:)` for `file://` URLs so content displays in-browser like Chrome. Using `load(URLRequest)` for file URLs can fail or trigger download; Capabilities alone don’t change that. |
| **Upload from Downloads** | Entitlement **User Selected File (read-write)** allows the app to read/write user-selected paths. The app still has to use the system file picker (or equivalent) so the user “selects” the file; that’s implemented in code. |
| **Download images / all file types** | Deciding when to show content vs download (e.g. by MIME type, main frame) is policy in the WKNavigationDelegate; it’s not an entitlement. |
| **Tab reorder, Cmd+1…9, zoom, appearance** | Pure UI and logic; no entitlement or framework controls these. |

---

## Summary

- **Signing & Capabilities** (and `Luma.entitlements`): use them for **sandbox and file/network access** (Downloads, User Selected File, Network). That’s all you need there for uploads and downloads to work.
- **Frameworks, Libraries, and Embedded Content**: only for linking frameworks; leave as-is for Luma.
- **Viewing files in the browser, tab/zoom/appearance behavior**: handled in code (e.g. `WebViewWrapper`, `TabManager`, `ContentView`, Settings).
