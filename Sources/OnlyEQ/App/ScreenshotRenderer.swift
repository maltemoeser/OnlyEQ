import AppKit
import SwiftUI

/// `OnlyEQ --screenshots <dir>` — renders the app's own views into offscreen
/// windows and saves PNGs. Used to generate README screenshots; needs no
/// screen-recording permission because it never captures the actual screen.
/// Add `--light` to render the light appearance as well (`*-light.png`).
@MainActor
enum ScreenshotRenderer {

    static func run(outputDir: String, includeLight: Bool) -> Int32 {
        AppState.screenshotMode = true
        let state = AppState.shared
        state.engineState = .running
        state.refreshDevices()

        // Demo preset: the HD 650 AutoEq fixture.
        if let url = Bundle.module.url(forResource: "Fixtures/autoeq_parametric.txt", withExtension: nil),
           var demo = try? PresetImporter.importFile(at: url).preset {
            demo.name = "HD 650 · oratory1990"
            demo.source = "AutoEq"
            state.preset = demo
            // In memory only: screenshot mode must not write the real profile store.
            if let device = state.currentDevice {
                state.store.deviceProfiles[device.uid] = DeviceProfile(
                    deviceUID: device.uid, deviceName: device.name, presetID: demo.id, presetName: demo.name)
            }
        }
        state.userVolumePercent = 65

        let dir = URL(fileURLWithPath: outputDir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let appearances: [(suffix: String, dark: Bool)] = includeLight
            ? [("", true), ("-light", false)] : [("", true)]

        var failures = 0
        for appearance in appearances {
            let dark = appearance.dark
            func save(_ name: String, _ view: some View) {
                let url = dir.appendingPathComponent(name + appearance.suffix + ".png")
                if !capture(view, dark: dark, to: url) { failures += 1 }
            }

            save("popover", canvas(
                PopoverView().environmentObject(state),
                panelRadius: PopoverView.cornerRadius, dark: dark))

            save("editor", canvas(
                windowChrome(EditorView(inlineToolbar: true).environmentObject(state).frame(width: 840, height: 540),
                             width: 840, inTitleBar: true),
                panelRadius: 12, dark: dark))

            save("import", canvas(
                windowChrome(ImportSheet().environmentObject(state), width: 560),
                panelRadius: 12, dark: dark))

            // The real window's toolbar tabs cannot render offscreen; this
            // shows the General page under plain window chrome.
            save("settings", canvas(
                windowChrome(SettingsPage.general.view.environmentObject(state)
                                .frame(width: SettingsPage.width).frame(minHeight: 360),
                             width: SettingsPage.width),
                panelRadius: 12, dark: dark))

            save("onboarding", canvas(
                windowChrome(OnboardingView().environmentObject(state),
                             width: OnboardingView.width, inTitleBar: true),
                panelRadius: 12, dark: dark))
        }

        let count = appearances.count * 5
        print(failures == 0 ? "Saved \(count) screenshots to \(dir.path)" : "\(failures) screenshot(s) failed")
        return failures == 0 ? 0 : 1
    }

    // MARK: - Styling

    /// Gradient backdrop with the content floating on a shadowed panel.
    /// Equal margins on all sides by construction — the capture window sizes
    /// itself from this view's fitting size.
    private static func canvas(_ content: some View, panelRadius: CGFloat, dark: Bool,
                               margin: CGFloat = 64) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: panelRadius, style: .continuous)
                    .fill(dark ? Color(red: 0.115, green: 0.115, blue: 0.125) : Color(red: 0.93, green: 0.93, blue: 0.94))
            )
            .clipShape(RoundedRectangle(cornerRadius: panelRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: panelRadius, style: .continuous)
                    .strokeBorder(dark ? Color.white.opacity(0.09) : Color.black.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(dark ? 0.5 : 0.25), radius: 28, y: 14)
            .padding(margin)
            .background(
                LinearGradient(
                    colors: dark
                        ? [Color(red: 0.19, green: 0.20, blue: 0.24), Color(red: 0.10, green: 0.10, blue: 0.13)]
                        : [Color(red: 0.86, green: 0.88, blue: 0.93), Color(red: 0.74, green: 0.77, blue: 0.84)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
    }

    /// Fake macOS window controls above the content. With `inTitleBar` the
    /// content draws its own title-bar row (the editor, onboarding), so the
    /// controls are overlaid on it instead of stacked above it. The explicit
    /// width matters: a Spacer would otherwise expand the panel to fill the
    /// whole canvas.
    private static func windowChrome(_ content: some View, width: CGFloat, inTitleBar: Bool = false) -> some View {
        let lights = HStack(spacing: 8) {
            Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 12, height: 12)
            Circle().fill(Color(red: 1.0, green: 0.75, blue: 0.18)).frame(width: 12, height: 12)
            Circle().fill(Color(red: 0.22, green: 0.78, blue: 0.25)).frame(width: 12, height: 12)
        }
        return Group {
            if inTitleBar {
                content
                    .overlay(alignment: .topLeading) {
                        lights
                            .padding(.leading, 20)
                            .frame(height: EditorView.toolbarHeight)
                    }
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        lights
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    content
                }
            }
        }
        .frame(width: width)
    }

    // MARK: - Offscreen capture

    /// Borderless windows refuse key status by default; controls in non-key
    /// windows draw untinted (gray switches), so allow it.
    private final class KeyableWindow: NSWindow {
        override var canBecomeKey: Bool { true }
    }

    /// Render in a real NSWindow (positioned far off-screen, but key, so
    /// AppKit-backed controls draw with their active tint), then snapshot the
    /// view hierarchy at Retina scale.
    private static func capture(_ view: some View, dark: Bool, to url: URL) -> Bool {
        let hosting = NSHostingController(rootView: view.environment(\.colorScheme, dark ? .dark : .light))
        let size = hosting.view.fittingSize
        let window = KeyableWindow(
            contentRect: NSRect(origin: NSPoint(x: -4000, y: -4000), size: size),
            styleMask: [.borderless],
            backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.isReleasedWhenClosed = false
        window.contentViewController = hosting
        window.setContentSize(size)
        window.setFrameOrigin(NSPoint(x: -4000, y: -4000))
        // Key but not activated: activating would steal focus from whatever
        // the person is doing while the batch renders.
        window.makeKeyAndOrderFront(nil)

        // Let SwiftUI settle its layout and control states.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.5))
        window.contentView?.needsDisplay = true
        window.displayIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

        // Off-screen windows render at 1x; build an explicit 2x rep for Retina.
        guard let contentView = window.contentView,
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width) * 2, pixelsHigh: Int(size.height) * 2,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
              ) else { return false }
        rep.size = size
        contentView.cacheDisplay(in: contentView.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try png.write(to: url)
            window.close()
            return true
        } catch {
            window.close()
            return false
        }
    }
}
