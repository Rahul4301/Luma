# Luma — MVP: UI/UX Focus

## What Luma Is

**Luma** is a macOS-native, AI-first browser. The web view is standard WebKit; the differentiator is a **context-aware AI command surface** (Cmd+E) that sees the current page (URL, title, visible text, optional selection) and can propose browser actions (new tab, navigate, close tab). The **chrome** (tabs + address bar) **unifies with the page** by sampling the page’s background color and switching to light or dark UI so the browser frame feels part of the page.

So: **browsing + light** (the page’s “luma”) **+ AI that understands the page.**

---

## MVP UI/UX Principles

### 1. **Chrome follows the page (DIA-style)**

- **Tabs and address bar** use a single color: either the **start-page dark** or the **active tab’s page background** (sampled from the loaded page).
- Text and icons on chrome are **light on dark** or **dark on light** based on luminance so they’re always readable.
- Goal: the frame doesn’t fight the page; it feels like one continuous surface.

### 2. **Minimal browser chrome**

- **Tab strip**: compact height (~38pt), traffic lights aligned, active tab shows chrome color; inactive area stays a consistent dark gray.
- **Address bar**: omnibox (URL or search), back/forward/reload, optional AI entry point.
- **No clutter**: no bookmarks bar, no extra toolbars in MVP. Focus is on content + one primary affordance: **Luma** (the AI panel).

### 3. **AI panel: calm, focused, transparent**

- **Trigger**: Cmd+E toggles a **right-side panel** (~380pt width, resizable).
- **Tone**: Soft, calm, professional — dark gray with slight warmth (no pure black), blue-slate accents when active.
- **Header**: “Luma” + short status (e.g. “Context-aware • Recent context”) + close. No heavy branding.
- **Context**: A collapsible “Context (always included)” shows what’s sent: URL, page title, page text snippet, optional selection. User sees exactly what the AI sees.
- **Chat**: Plain, scrollable history; user messages right-aligned in a subtle bubble; assistant replies left-aligned, no bubble. Markdown supported.
- **Input**: Single text field, “Message Luma…” placeholder, Enter to send, optional “Include selection” toggle. Focus state: soft blue-slate glow (Xcode-assistant style), not harsh.
- **Actions**: When the model proposes an action (e.g. open URL, close tab), the app shows a **confirmation**; the user approves or dismisses. No automatic execution without consent.

### 4. **Start page**

- When there’s no loaded URL, show a **start/landing** view: clean, dark, centered. One clear entry point (e.g. search or URL field). Optional short tagline that reinforces “browse + AI that knows the page.”

### 5. **Typography and spacing**

- **System fonts** (San Francisco on macOS). Clear hierarchy: title/section 14pt semibold, body 13pt, captions 9–11pt.
- **Rounded corners**: 14–18pt continuous radius for panels and key controls so the app feels modern and cohesive.
- **Padding**: Generous enough that the UI doesn’t feel cramped (e.g. 16–18pt horizontal in the AI panel).

### 6. **Color and “Luma”**

- **Luma** = light / luminance. The product literally uses **page luminance** to drive chrome contrast.
- **Palette**: Dark gray base (~0.09–0.14), warm rather than cold; accent blue-slate (~0.45, 0.58, 0.72) for focus and links; red only for errors; green for “ready” status.
- Logo and icon should **echo “light” and “browser”** — a glow, a lens, or a single clear symbol that reads as “this app brings light/context to the web.”

---

## MVP Scope (UI/UX)

| In scope | Out of scope (post-MVP) |
|----------|--------------------------|
| Tabs, address bar, back/forward/reload | Bookmarks bar, extensions |
| Chrome color from page theme | Custom themes / user-picked chrome color |
| Cmd+E AI panel, context preview, confirm actions | Inline AI, auto-actions, voice |
| Start page with search/URL | Rich start page widgets |
| Downloads list / hub | Sync, history search UI |
| One clear “Luma” entry (panel + optional icon in chrome) | Multiple AI surfaces |

---

## Logo and Brand (for AI image prompt)

The logo should capture:

1. **Light / luminance** — “Luma” = light; the app uses page light to adapt the UI.
2. **Browser** — window, frame, or view onto content.
3. **Clarity and calm** — soft, professional, not playful or noisy.
4. **Single iconic abstract shape** — no letters. Works at 16×16 (favicon) and at larger sizes; readable in light and dark.

Avoid: generic globes, generic chat bubbles, clip-art "AI" robots, and any letters or letterforms. Prefer: abstract shape only — e.g. abstract glow, minimal lens/window, or a simple aperture/beam form that suggests light.

---

*This MVP doc is the source of truth for UI/UX. The Gemini logo prompt below is derived from it.*
