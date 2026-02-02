// Luma MVP - Favicon for tabs and history
import SwiftUI

/// Loads and displays a site favicon from URL (e.g. domain/favicon.ico).
struct FaviconView: View {
    let url: URL
    private var faviconURL: URL? {
        guard let host = url.host, !host.isEmpty else { return nil }
        return URL(string: "https://\(host)/favicon.ico")
    }

    var body: some View {
        Group {
            if let fav = faviconURL {
                AsyncImage(url: fav) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.5)
                    @unknown default:
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
