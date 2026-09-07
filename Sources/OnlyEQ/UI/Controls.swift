import AppKit
import SwiftUI

/// macOS-switch lookalike drawn in pure SwiftUI. AppKit's NSSwitch doesn't
/// render its state when drawn into an offscreen window (which breaks the
/// --screenshots mode), and this also guarantees an identical look everywhere.
///
/// The capsule takes keyboard focus, toggles on Space, and presents itself to
/// VoiceOver as the Toggle it stands in for, so it behaves like the real
/// control and not like a picture of one.
struct AccentSwitchStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var width: CGFloat = 34

    func makeBody(configuration: Configuration) -> some View {
        let height = width * 0.585
        return HStack {
            configuration.label
            Capsule()
                .fill(configuration.isOn ? Color.accentColor : Color.primary.opacity(0.18))
                .frame(width: width, height: height)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                        .padding(1.5)
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isOn)
                .contentShape(Capsule())
                .onTapGesture { configuration.isOn.toggle() }
                .focusable()
                .onKeyPress(.space) {
                    configuration.isOn.toggle()
                    return .handled
                }
        }
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

/// The system's own menu-bar-extra material: Liquid Glass on macOS 26, the
/// popover vibrancy material before it. The panel that hosts the popover is
/// borderless and clear, so this is what stands between the content and the
/// desktop.
struct PanelMaterial: NSViewRepresentable {
    var cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSView {
        // NSGlassEffectView exists only in the macOS 26 SDK (Swift 6.2 and
        // later); an older toolchain builds the vibrancy fallback everywhere.
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = cornerRadius
            glass.style = .regular
            return glass
        }
        #endif
        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = cornerRadius
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true
        return effect
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

/// A row that names one thing the listener is using: a circled SF Symbol, a
/// menu holding the name, and whatever belongs underneath (volume, binding).
/// The popover's device and preset rows share this so they read as siblings.
struct IdentityRow<Menu: View, Detail: View>: View {
    var symbol: String
    var symbolLabel: String
    @ViewBuilder var menu: Menu
    @ViewBuilder var detail: Detail

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.primary.opacity(0.07)))
                    .accessibilityLabel(symbolLabel)
                menu
                Spacer(minLength: 0)
            }
            detail
                .padding(.leading, 38)
        }
    }
}

/// The gear: the same menu behind the same glyph in the popover and the
/// editor, since an accessory app has no menu bar to hold these.
struct AppGearMenu: View {
    var body: some View {
        Menu {
            Button("Settings…") { WindowManager.shared.showSettings() }
                .keyboardShortcut(",", modifiers: .command)
            Button("Check for Updates…") {
                (NSApp.delegate as? AppDelegate)?.checkForUpdates()
            }
            Divider()
            Button("Quit OnlyEQ") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "gearshape")
        }
        .help("Settings, updates, quit")
        .accessibilityLabel("Settings, updates, quit")
    }
}

/// The system search field, for lists a person filters by typing.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    var prompt: String

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = prompt
        field.delegate = context.coordinator
        field.sendsSearchStringImmediately = true
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.text = $text
        field.placeholderString = prompt
        if field.stringValue != text { field.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) { self.text = text }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

/// The one surface the app draws: a 3.5 % tint with an 8 % hairline at a
/// 10 pt continuous corner. Every plot outside the editor's canvas sits in
/// it, and the import drop zone borrows it.
struct PlotWell: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.035)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

extension View {
    func plotWell() -> some View { modifier(PlotWell()) }
}

/// Wordmark as a small rounded badge, used wherever the app names itself.
struct AppBadge: View {
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: OnlyEQIcon.symbolName)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous).fill(Color.accentColor))
            .accessibilityHidden(true)
    }
}
