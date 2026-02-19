// Safari-style chrome: colors, tab bar, and toolbar styling for Luma
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Safari chrome colors (dark mode native)

enum SafariChrome {
    static let toolbarBackground = Color(white: 0.14)
    static let tabBarBackground = Color(white: 0.12)
    static let inactiveTabBackground = Color(white: 0.20)
    static let inactiveTabHover = Color(white: 0.24)
    static let textPrimary = Color.white
    static let textMuted = Color.white.opacity(0.72)
    static let addressBarBackground = Color.white.opacity(0.10)
    static let addressBarFocusRing = Color.accentColor
}

// MARK: - Safari-style tab strip (tabs below toolbar; Start Page + star; rounded top only)

struct SafariTabStripView: View {
    @ObservedObject var tabManager: TabManager
    let faviconURLByTab: [UUID: URL?]
    let activeTabColor: Color
    let chromeTextIsLight: Bool
    let onSwitch: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onNewTab: () -> Void
    let onDropURLForNewTab: (URL) -> Void
    let onReorder: (Int, Int) -> Void

    @State private var draggedTab: UUID?
    private let rowHeight: CGFloat = 28

    private static let minTabWidth: CGFloat = 84
    private static let maxTabWidth: CGFloat = 220
    private static let emergencyMinTabWidth: CGFloat = 48
    private static let newTabButtonWidth: CGFloat = 28
    private static let newTabGap: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let N = tabManager.tabCount()
            let W = max(0, geometry.size.width - Self.newTabButtonWidth - Self.newTabGap)
            let ideal = N > 0 ? W / CGFloat(N) : 0
            let tabWidth: CGFloat = N > 0
                ? min(Self.maxTabWidth, ideal >= Self.minTabWidth ? ideal : max(Self.emergencyMinTabWidth, ideal))
                : 0

            HStack(spacing: 0) {
                ForEach(Array(tabManager.tabOrder.enumerated()), id: \.element) { index, tabId in
                    SafariTabPill(
                        tabId: tabId,
                        index: index + 1,
                        url: tabManager.tabURL[tabId] ?? nil,
                        title: tabManager.tabTitle[tabId],
                        faviconURL: faviconURLByTab[tabId] ?? nil,
                        isActive: tabManager.currentTab == tabId,
                        activeTabColor: activeTabColor,
                        chromeTextIsLight: chromeTextIsLight,
                        showTitle: tabWidth >= Self.minTabWidth,
                        onSelect: { onSwitch(tabId) },
                        onClose: { onClose(tabId) }
                    )
                    .background(NonDraggableWindowView())
                    .frame(width: tabWidth, height: rowHeight)
                    .id(tabId)
                    .opacity(draggedTab == tabId ? 0.5 : 1.0)
                    .onDrag {
                        draggedTab = tabId
                        return NSItemProvider(object: tabId.uuidString as NSString)
                    }
                    .onDrop(of: [.plainText], delegate: SafariTabDropDelegate(
                        destinationTab: tabId,
                        tabs: tabManager.tabOrder,
                        draggedTab: $draggedTab,
                        onReorder: onReorder
                    ))
                }

                Button(action: onNewTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(SafariChrome.textMuted)
                        .frame(width: Self.newTabButtonWidth, height: rowHeight - 2)
                        .contentShape(Rectangle())
                }
                .background(NonDraggableWindowView())
                .buttonStyle(.plain)
                .accessibilityLabel("New tab")
                .onDrop(of: [.url, .fileURL, .plainText], isTargeted: nil) { providers in
                    urlDropHandler(providers: providers)
                }

                WindowDragRegionView()
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(true)
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.06), value: tabManager.tabCount())
            .animation(.easeInOut(duration: 0.06), value: geometry.size.width)
        }
        .frame(maxWidth: .infinity)
        .onDrop(of: [.url, .fileURL, .plainText], isTargeted: nil) { providers in
            urlDropHandler(providers: providers)
        }
    }

    private func urlDropHandler(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let u = url, (u.scheme == "http" || u.scheme == "https" || u.scheme == "file") {
                    DispatchQueue.main.async { onDropURLForNewTab(u) }
                }
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let u = url { DispatchQueue.main.async { onDropURLForNewTab(u) } }
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            _ = provider.loadObject(ofClass: String.self) { str, _ in
                if let s = str?.trimmingCharacters(in: .whitespacesAndNewlines),
                   let u = URL(string: s),
                   u.scheme == "http" || u.scheme == "https" {
                    DispatchQueue.main.async { onDropURLForNewTab(u) }
                }
            }
        }
        return true
    }
}

private struct SafariTabPill: View {
    let tabId: UUID
    let index: Int
    let url: URL?
    let title: String?
    let faviconURL: URL?
    let isActive: Bool
    let activeTabColor: Color
    let chromeTextIsLight: Bool
    let showTitle: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHovered = false

    private var displayTitle: String {
        if let title = title, !title.isEmpty { return title }
        if url == nil || url?.absoluteString == "about:blank" { return "Start Page" }
        if url?.scheme == "luma", url?.host == "history" { return "History" }
        if url?.scheme == "luma", url?.host == "ai" { return "AI Chat" }
        if url?.scheme == "file" { return url?.lastPathComponent ?? "File" }
        return url?.host ?? url?.absoluteString ?? "Start Page"
    }

    private var isStartPage: Bool {
        url == nil || url?.absoluteString == "about:blank"
    }

    private var tabTextColor: Color {
        if isActive { return chromeTextIsLight ? SafariChrome.textPrimary : Color(white: 0.15) }
        return SafariChrome.textMuted
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: showTitle ? 6 : 0) {
                    Group {
                        if isStartPage {
                            Image(systemName: "star")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(tabTextColor)
                        } else if url?.scheme == "luma", url?.host == "ai" {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(tabTextColor)
                        } else if let url = url {
                            FaviconView(url: url, faviconURL: faviconURL)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "star")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(tabTextColor)
                        }
                    }
                    .frame(width: 14, height: 14, alignment: .center)
                    if showTitle {
                        Text(displayTitle)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(tabTextColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, showTitle ? 4 : 6)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(tabTextColor.opacity(0.85))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered || isActive ? 1 : 0)
            .allowsHitTesting(isHovered || isActive)
        }
        .onHover { isHovered = $0 }
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 8)
                .fill(isActive ? activeTabColor : (isHovered ? SafariChrome.inactiveTabHover : SafariChrome.inactiveTabBackground))
        )
        .animation(.easeInOut(duration: 0.06), value: activeTabColor)
        .animation(.easeInOut(duration: 0.06), value: isHovered)
        .animation(.easeInOut(duration: 0.06), value: isActive)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tab \(index): \(displayTitle)")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

private struct SafariTabDropDelegate: DropDelegate {
    let destinationTab: UUID
    let tabs: [UUID]
    @Binding var draggedTab: UUID?
    let onReorder: (Int, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedTab = draggedTab else { return }
        guard let fromIndex = tabs.firstIndex(of: draggedTab),
              let toIndex = tabs.firstIndex(of: destinationTab),
              fromIndex != toIndex else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            onReorder(fromIndex, toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedTab = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
