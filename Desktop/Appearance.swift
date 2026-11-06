import SwiftUI
import AppKit

enum WidgetBackground: String, CaseIterable, Identifiable {
    case black, dark, darkGlass, glass
    var id: String { rawValue }
    var title: String {
        switch self { case .black: return "黒"; case .dark: return "ダーク"; case .darkGlass: return "ダークグラス"; case .glass: return "グラス" }
    }
    var detail: String {
        switch self {
        case .black: return "引き締まった、完全な黒の背景"
        case .dark: return "落ち着いたチャコールの背景"
        case .darkGlass: return "暗い色合いを重ねた、すりガラスの背景"
        case .glass: return "壁紙が透ける、軽やかなグラスの背景"
        }
    }
}
struct DesktopBackground: View {
    let style: WidgetBackground
    var body: some View {
        Group {
            switch style {
            case .black: Color.black
            case .dark: Color(white: 0.065)
            case .darkGlass:
                ZStack { BackdropGlass(opacity: 0.95); Color.black.opacity(0.32) }
            case .glass:
                ZStack { BackdropGlass(opacity: 0.95, light: true); Color.white.opacity(0.08) }
            }
        }
        .overlay {
            if style == .glass || style == .darkGlass {
                RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(style == .glass ? 0.24 : 0.12), lineWidth: 1)
            }
        }
    }
}
struct BackdropGlass: NSViewRepresentable {
    let opacity: Double
    var light = false
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = light ? .popover : .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: light ? .aqua : .darkAqua)
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) { view.alphaValue = opacity }
}

// Own mouse tracking distinguishes a click from a drag, so moving the card never opens Codex.
final class CardMouseView: NSView {
    var openCodex: () -> Void = {}
    var openSettings: () -> Void = {}
    private var down: NSEvent?
    private var dragged = false
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { openSettings(); return }
        down = event; dragged = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard !dragged, let down else { return }
        let start = down.locationInWindow, current = event.locationInWindow
        guard hypot(current.x - start.x, current.y - start.y) >= 4 else { return }
        dragged = true
        window?.performDrag(with: down)
        self.down = nil
    }
    override func mouseUp(with event: NSEvent) {
        defer { down = nil; dragged = false }
        if down != nil && !dragged { openCodex() }
    }
    override func rightMouseDown(with event: NSEvent) { openSettings() }
    override func accessibilityPerformPress() -> Bool { openCodex(); return true }
}
struct CardInteraction: NSViewRepresentable {
    let openCodex: () -> Void
    let openSettings: () -> Void
    func makeNSView(context: Context) -> CardMouseView {
        let view = CardMouseView()
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.button)
        view.setAccessibilityLabel("Codexを開く")
        view.setAccessibilityHelp("クリックでCodexを開く。右クリックで設定。ドラッグで移動。")
        return view
    }
    func updateNSView(_ view: CardMouseView, context: Context) {
        view.openCodex = openCodex; view.openSettings = openSettings
    }
}
