import SwiftUI
import AppKit

// Compose the original logo and UI shapes without redrawing the brand mark.
@main struct RenderIcon {
    @MainActor static func main() throws {
        let logo = NSImage(contentsOfFile: CommandLine.arguments[1])!
        let icon = ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.12), Color(white: 0.055)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 185, style: .continuous).strokeBorder(.white.opacity(0.09), lineWidth: 2))
                .frame(width: 824, height: 824)
            VStack(spacing: 80) {
                Image(nsImage: logo).resizable().scaledToFit().frame(width: 430, height: 430)
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule().fill(Color(red: 0.66, green: 0.85, blue: 0.96)).frame(width: 410)
                }.frame(width: 560, height: 34)
            }.offset(y: -3)
        }.frame(width: 1024, height: 1024)
        let renderer = ImageRenderer(content: icon)
        renderer.scale = 1
        guard let image = renderer.nsImage, let data = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data), let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Rendering failed") }
        try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
    }
}
