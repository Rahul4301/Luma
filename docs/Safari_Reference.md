# Safari Reference for Luma (Safari Clone + AI)

Reference for building a Safari-like UI and feature set in Luma, with integrated AI. Covers open-source status, official docs, UI elements, icons, and feature parity.

---

## 1. Is Safari Open Source?

**Safari the application is not open source.** The full Safari app (chrome, tabs, settings UI, start page) is proprietary Apple code.

**WebKit is open source** and is the engine that powers Safari (and Luma):

- **WebKit**: [https://webkit.org](https://webkit.org) — BSD-style license  
- **Source**: [https://github.com/WebKit/WebKit](https://github.com/WebKit/WebKit)  
- **Apple Open Source**: [https://opensource.apple.com/projects/webkit](https://opensource.apple.com/projects/webkit)

So: we use the same engine (WebKit) as Safari, but the **browser chrome, tabs, address bar, settings, and start page** must be implemented by us to *look and behave* like Safari. There is no official “Safari UI source code” to clone.

---

## 2. Safari & Apple Documentation

| Resource | URL | Use |
|----------|-----|-----|
| **Safari for developers** | [developer.apple.com/safari](https://developer.apple.com/safari) | Web tech in Safari (extensions, Web Push, Passkeys, etc.) |
| **Safari Developer Help** | [support.apple.com/guide/safari-developer](https://support.apple.com/guide/safari-developer/welcome/mac) | Develop menu, Web Inspector, debugging |
| **Human Interface Guidelines** | [developer.apple.com/design/human-interface-guidelines](https://developer.apple.com/design/human-interface-guidelines) | macOS/iOS UI patterns, toolbars, layout |
| **SF Symbols** | [developer.apple.com/sf-symbols](https://developer.apple.com/sf-symbols) | System icon set (6,900+ symbols) for Safari-like icons |
| **WebKit** | [webkit.org](https://webkit.org), [webkit.org/getting-the-code](https://webkit.org/getting-the-code) | Engine docs and source |

There is **no** dedicated “Safari app UI” spec; Safari’s look and behavior are inferred from the app and from the HIG (toolbars, tabs, navigation).

---

## 3. Safari UI Elements (from reference screenshots)

### 3.1 Window and chrome

- **Traffic lights**: Red / yellow / green (close, minimize, maximize) — standard macOS; Luma already has this via SwiftUI/AppKit.
- **Dark mode**: Safari chrome is dark grey/black; tabs and address bar use the same dark theme. Luma’s MVP already uses theme-aware chrome (e.g. `chromeColor`, `chromeTextIsLight` in `BrowserShellView`).

### 3.2 Toolbar (left → right)

| Element | Description | Luma equivalent |
|--------|--------------|------------------|
| Tab overview | Icon: two overlapping rectangles + caret (show all tabs) | Could add tab overview / tab grid |
| Back / Forward | `<` and `>` in a rounded group | ✅ `BrowserShellView` |
| **Address bar (omnibox)** | Single rounded bar: “Search or enter website name”, magnifying glass on left, blue focus ring | ✅ `SmartSearchView` / address bar |
| Share / upload | Square with up arrow | Optional (share sheet) |
| New tab | `+` button | ✅ New tab |
| Sidebar toggle | Rectangle + small overlapping rectangle (bookmarks/sidebar) | Optional (reading list / bookmarks) |

### 3.3 Tab bar

- **Placement**: Directly below the address bar (or in “compact” layout, same row as address bar on some macOS versions).
- **Tabs**: Rounded top corners; **active tab** has lighter background and shows a star for “Start Page”; **inactive** tabs are darker, show favicon + title (e.g. “Google Docs”).
- **Behavior**: Drag to reorder (Luma has this), Cmd+1…9 to switch (Luma has this). Safari also has “Show color in tab bar” (tab bar tint from page).
- **Start Page tab**: Label “Start Page” with star icon; Luma has `StartPageView` and can label the tab similarly.

### 3.4 Start page

- **Background**: Dark, subtle gradient/blur (Luma’s `StartPageView` already uses dark glassmorphism).
- **Center**: One prominent “Search or enter website name” field (Luma: “Search the web…”).
- **Edit (bottom-right)**: Safari has “Edit” to customize start page sections (Favorites, Suggestions, Privacy Report, Reading List, iCloud Tabs, Recently Closed Tabs, Background Image). Luma can add an “Edit” that opens start-page preferences.

### 3.5 Settings window (Safari Preferences)

- **Window title**: Matches the selected section (e.g. “General”, “Tabs”, “Privacy”).
- **Top nav**: Horizontal bar with **icons + labels** for each section. Icons are monochrome (e.g. white/light grey on dark).
- **Sections** (for Safari-style settings in Luma):

  | Section   | Icon (concept)        | Purpose |
  |-----------|------------------------|---------|
  | General   | Gear                  | Default browser, new window/tab behavior, homepage, history, downloads |
  | Tabs      | Two overlapping rects | Open in tabs, auto-close, “Show color in tab bar”, ⌘-click, ⌘-1…9 |
  | AutoFill  | Pen on document       | Contacts, usernames/passwords, credit cards, other forms |
  | Passwords | Key                   | Passwords app / keychain |
  | Search    | Magnifying glass      | Search engine, Smart Search, suggestions, Quick Website Search |
  | Security  | Padlock               | Fraudulent sites, JavaScript, HTTP warning |
  | Privacy   | Hand                  | Cross-site tracking, hide IP, website data, locked tabs |
  | Websites  | Globe                 | Per-site settings |
  | Profiles  | Person                | Separate personal/work profiles |
  | Extensions| Puzzle piece          | Extensions |
  | Advanced  | Two gears             | Advanced options |

Luma currently has a simpler `SettingsView` (e.g. General, AI & Models). To mirror Safari we can add an icon strip and more panes (Tabs, Search, Privacy, etc.) and reuse **SF Symbols** for the same icon concepts.

---

## 4. Safari Icons (for the clone)

- **Source**: **SF Symbols** ([developer.apple.com/sf-symbols](https://developer.apple.com/sf-symbols)). Use the same semantic icons as Safari where possible.
- **Suggested SF Symbol names** (match Safari’s meaning; exact names can be looked up in SF Symbols app):
  - General: `gearshape` / `gearshape.fill`
  - Tabs: `square.stack` / `square.on.square`
  - AutoFill: `doc.text` or form-related
  - Passwords: `key` / `key.fill`
  - Search: `magnifyingglass`
  - Security: `lock` / `lock.fill`
  - Privacy: `hand.raised` / `hand.raised.fill`
  - Websites: `globe`
  - Profiles: `person` / `person.crop.circle`
  - Extensions: `puzzlepiece.extension` / `puzzlepiece.extension.fill`
  - Advanced: `gearshape.2` / similar
  - Back: `chevron.left`
  - Forward: `chevron.right`
  - New tab: `plus`
  - Share: `square.and.arrow.up`
  - Sidebar: `rectangle.leadinghalf.inset.filled` or `sidebar.left`
  - Start page / Favorites: `star` / `star.fill`
  - Tab overview: `square.stack.3d.up` or similar

Using these in SwiftUI (e.g. `Image(systemName: "gearshape")`) gives a Safari-like, native look.

---

## 5. Safari Features (summary for parity)

From the reference screenshots and docs, features that are relevant for a “Safari clone + AI”:

- **Tabs**: Multiple tabs, reorder, Cmd+1…9, ⌘-click = new tab, “Show color in tab bar”, optional auto-close. **Luma**: tabs and shortcuts exist; “color in tab bar” and auto-close are good additions.
- **Start page**: Customizable (Favorites, Suggestions, Recently Closed, Background). **Luma**: start page exists; “Edit” and sections (e.g. recently closed, favorites) can be added.
- **General**: Homepage, new window/tab behavior, history retention, download location. **Luma**: can add in Settings.
- **Search**: Default search engine, suggestions, Quick Website Search. **Luma**: has address bar and search; can align options with Safari’s Search pane.
- **Security / Privacy**: Fraud warning, JavaScript, tracking prevention. **Luma**: can add toggles in Settings (and later hook to WebKit where applicable).
- **Profiles**: Separate personal/work. **Luma**: post-MVP.
- **Extensions**: Safari Web Extensions. **Luma**: post-MVP per MVP doc.

---

## 6. Luma vs Safari (quick map)

| Area | Safari | Luma now | Suggested direction |
|------|--------|----------|----------------------|
| Engine | WebKit | WebKit ✅ | Keep |
| Tabs | Rounded, reorder, Cmd+1–9, color from page | Tabs, reorder, Cmd+1–9, theme from page | Add “Show color in tab bar” pref; align tab shape/labels (e.g. “Start Page” + star) |
| Address bar | Omnibox, “Search or enter website name” | Omnibox, “Search the web…” | Optionally match placeholder; keep blue focus ring style |
| Start page | Dark, centered search, Edit → sections | Dark, centered search | Add “Edit” → Favorites / Recently closed / background options |
| Settings | Icon strip (General, Tabs, Search, …) | General, AI & Models | Add Safari-style icon strip + Tabs, Search, Privacy, Security panes |
| Icons | SF Symbols (gear, key, lock, etc.) | Likely SF Symbols already | Standardize on SF Symbol names above for Safari-like feel |
| AI | None | Cmd+E panel, context-aware commands | Keep and expand (differentiator) |

---

## 7. References (links)

- [WebKit](https://webkit.org)
- [WebKit on GitHub](https://github.com/WebKit/WebKit)
- [Safari – Apple Developer](https://developer.apple.com/safari)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)
- [SF Symbols](https://developer.apple.com/sf-symbols)
- [Safari Developer Help (Mac)](https://support.apple.com/guide/safari-developer/welcome/mac)

Use this doc when implementing or refining Safari-like tabs, icons, settings layout, and start page in Luma.
