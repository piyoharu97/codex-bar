import SwiftUI
import AppKit

enum IconChoice: String, CaseIterable, Identifiable {
    case codex, chatGPT
    var id: String { rawValue }
    var title: String { self == .codex ? "Codex" : "ChatGPT" }
    var logoResource: String { self == .codex ? "CodexLogo" : "ChatGPTLogo" }
    var iconResource: String { self == .codex ? "CodexBarIcon" : "ChatGPTBarIcon" }
    var logo: Image {
        if let url = Bundle.main.url(forResource: logoResource, withExtension: "png"), let image = NSImage(contentsOf: url) {
            return Image(nsImage: image)
        }
        return Image(systemName: "terminal")
    }
    var appIcon: NSImage? {
        guard let url = Bundle.main.url(forResource: iconResource, withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }
}
