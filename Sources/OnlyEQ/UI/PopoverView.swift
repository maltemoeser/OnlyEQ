import SwiftUI

// DIRECTION CONTRACT (surface seed 1512465f; the user pinned the stacked
//   form over the rolled two-pane one)
// THESIS: The curve is the product, so the popover is one instrument rather
//   than a stack of cards. The live response spans the full width under the
//   name and switch; the controls follow beneath it and read top to bottom
//   as the signal path. Refused: three same-size cards.
// OWN-WORLD: macOS itself. The system's menu-bar material, the system accent,
//   San Francisco, native menus and bordered buttons. The only chromatic mark
//   is the accent curve breathing over the grey input spectrum. No cards:
//   rows are separated by space; the plot alone sits in a hairline well, the
//   one surface the app draws. Every plot outside the editor's canvas sits in
//   the same one.
// STORY: Open, watch the curve under the music, see which device and preset
//   are live, flip Bypass to hear it flat, close. Editing happens elsewhere.
// FIRST VIEWPORT: 360 pt wide, about 430 tall. OnlyEQ and its switch; the
//   plot, 150 pt, with its axis and a status pill in the corner; output
//   device with volume; preset with its device binding and Bypass |
//   Crossfeed; Import…, Equalizer, and the gear at the bottom.
// FORM: curve-first stack, candidate 2 of the grounded list, chosen by the
//   user over the rolled candidate 7 (key 1512465f).
// FINISH: unreviewed and undocumented is unfinished; this build ends with
//   the finish review, the verdict, and DESIGN.md.

/// Main menu-bar popover: name and switch, the live curve, then the controls
/// in signal order.
struct PopoverView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("showLatency") private var showLatency = true

    static let width: CGFloat = 360
    static let minHeight: CGFloat = 420
    static let cornerRadius: CGFloat = 14
    static let plotHeight: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            curvePane
            Group {
                deviceRow
                presetRow
            }
            .disabled(!state.isEnabled)
            .opacity(state.isEnabled ? 1 : 0.45)
            footer
        }
        .padding(14)
        // Sized once when shown so the host panel never resizes while open;
        // it grows only with the system text size.
        .frame(width: Self.width, alignment: .top)
        .frame(minHeight: Self.minHeight, alignment: .top)
        .onExitCommand {
            NotificationCenter.default.post(name: .onlyEQHideMenuPanel, object: nil)
        }
    }

    // MARK: - Curve pane

    private var curvePane: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                if state.suspectedPermissionIssue {
                    permissionNotice
                } else {
                    curveButton
                    statusIndicator
                        .padding(8)
                }
                if let suggestion = state.pendingProfileSuggestion,
                   suggestion.deviceUID == state.currentDevice?.uid {
                    suggestionNotice(suggestion)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.plotHeight)
            .plotWell()
            FrequencyAxisLabels(compact: true)
                .padding(.horizontal, 1)
        }
        .opacity(state.isEnabled ? 1 : 0.45)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: state.isEnabled)
    }

    private var curveButton: some View {
        Button {
            WindowManager.shared.showEditor()
        } label: {
            EQCurveView(bands: state.bypassed ? [] : state.preset.bands, preampDB: 0,
                        showSpectrum: state.isEnabled && state.popoverIsVisible,
                        spectrumStyle: .normal, rangeDB: state.preset.displayRangeDB)
                .padding(.vertical, 1)
                .opacity(state.bypassed ? 0.5 : 1)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: state.bypassed)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open the equalizer")
        .accessibilityLabel("EQ curve")
        .accessibilityHint("Opens the equalizer")
    }

    private var statusIndicator: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.caption2.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(.background.opacity(0.6)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status")
        .accessibilityValue(statusText)
    }

    private var statusColor: Color {
        guard state.isEnabled else { return .secondary }
        switch state.engineState {
        case .running:
            if state.suspectedPermissionIssue { return .orange }
            return state.bypassed ? .secondary : .green
        case .stopped: return .secondary
        case .failed: return .red
        }
    }

    private var statusText: String {
        guard state.isEnabled else { return "Off" }
        switch state.engineState {
        case .running:
            if state.suspectedPermissionIssue { return "Waiting for audio" }
            if state.bypassed { return "Bypassed" }
            return showLatency ? "Active · \(state.latencyMilliseconds) ms" : "Active"
        case .stopped: return "Off"
        case .failed: return "Error"
        }
    }

    /// Replaces the old behaviour of opening the equalizer with an import
    /// sheet the moment new headphones connect. The offer waits here instead.
    private func suggestionNotice(_ suggestion: ProfileSuggestion) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "headphones.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text("New headphones")
                    .font(.callout.weight(.semibold))
                Text("Find a preset tuned for \(suggestion.deviceName)?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("Find Preset") {
                        state.pendingProfileSuggestion = nil
                        WindowManager.shared.showEditor(importing: true, profileSuggestion: suggestion)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Not Now") { state.pendingProfileSuggestion = nil }
                }
                .controlSize(.small)
                .padding(.top, 2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.background.opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    }

    private var permissionNotice: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
            Text("Confirm System Audio access")
                .font(.callout.weight(.semibold))
            Text("Play any audio to confirm. If it stays silent, allow OnlyEQ in System Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open System Settings") { PermissionHelper.openSystemSettings() }
                .controlSize(.small)
                .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Controls

    private var header: some View {
        HStack(spacing: 8) {
            AppBadge()
            Text("OnlyEQ").font(.body.weight(.semibold))
            Spacer()
            Toggle("", isOn: $state.isEnabled)
                .toggleStyle(AccentSwitchStyle())
                .labelsHidden()
                .accessibilityLabel("Enable EQ")
        }
    }

    private var deviceRow: some View {
        IdentityRow(symbol: state.currentDevice?.icon ?? "speaker.slash", symbolLabel: "Output device") {
            Menu {
                ForEach(state.devices) { device in
                    Button {
                        state.selectOutputDevice(device)
                    } label: {
                        if device.id == state.currentDevice?.id {
                            Label(device.name, systemImage: "checkmark")
                        } else {
                            Text(device.name)
                        }
                    }
                }
            } label: {
                menuLabel(state.currentDevice?.name ?? "No Output Device")
            }
            .menuStyle(.borderlessButton)
            .fixedSize(horizontal: false, vertical: true)
            .help("Output device")
        } detail: {
            BoostSlider(
                value: $state.userVolumePercent,
                maxPercent: state.maxBoostPercent,
                onPreview: { state.previewVolumeAdjustment($0) },
                onEditingChanged: { editing in
                    if editing {
                        state.beginVolumeAdjustment()
                    } else {
                        state.endVolumeAdjustment()
                    }
                }
            )
        }
    }

    private var presetRow: some View {
        IdentityRow(symbol: "slider.horizontal.3", symbolLabel: "Preset") {
            Menu {
                ForEach(state.store.allPresets) { preset in
                    Button(preset.name) { state.apply(preset) }
                }
                if let stored = state.savedPreset, state.store.customPresets.contains(stored) {
                    Divider()
                    Button("Delete “\(stored.name)”…", role: .destructive) {
                        WindowManager.shared.confirmDeletePreset(stored)
                    }
                }
            } label: {
                menuLabel(state.preset.name)
            }
            .menuStyle(.borderlessButton)
            .fixedSize(horizontal: false, vertical: true)
            .help(presetBindingCaption.map { "\($0). Choose a preset to use it on this device." } ?? "Preset")
        } detail: {
            VStack(alignment: .leading, spacing: 8) {
                // The binding that makes "set once" work is otherwise
                // invisible; name it under the preset, or offer it.
                if let caption = presetBindingCaption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let device = state.currentDevice {
                    Button("Use on \(device.name) automatically") {
                        state.bindPresetToCurrentDevice()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                    .help("Apply this preset whenever \(device.name) becomes the output")
                }
                HStack(spacing: 6) {
                    Toggle("Bypass", isOn: $state.bypassed)
                        .help("Hear the unprocessed signal without changing the preset")
                    Toggle("Crossfeed", isOn: $state.crossfeedEnabled)
                        .help("Blend a little of each channel into the other for headphones")
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func menuLabel(_ name: String) -> some View {
        Text(name)
            .font(.body.weight(.medium))
            .lineLimit(1)
            .truncationMode(.middle)
    }

    /// "Auto on External Headphones" while the current preset is the one
    /// stored for the current device; nil when the preset is only a stash.
    private var presetBindingCaption: String? {
        guard let device = state.currentDevice,
              let profile = state.store.deviceProfiles[device.uid],
              state.presetIsBoundToCurrentDevice else { return nil }
        return profile.autoApply ? "Auto on \(device.name)" : "Saved for \(device.name)"
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Button {
                WindowManager.shared.showEditor(importing: true)
            } label: {
                Label("Import…", systemImage: "square.and.arrow.down")
            }
            Button {
                WindowManager.shared.showEditor()
            } label: {
                Label("Equalizer", systemImage: "slider.horizontal.3")
            }
            Spacer(minLength: 0)
            AppGearMenu()
                .menuStyle(.borderlessButton)
                .fixedSize()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

/// Volume slider: blue track to 100 %, orange boost zone beyond, tick at 100 %.
struct BoostSlider: View {
    @Binding var value: Double
    var maxPercent: Double
    var onPreview: (Double) -> Void = { _ in }
    var onEditingChanged: (_ editing: Bool) -> Void = { _ in }
    private let knobDiameter: CGFloat = 15
    @State private var trackedValue: Double?
    @State private var lastPreviewTime: TimeInterval = 0
    @State private var previewInterval: TimeInterval = 1.0 / 60.0
    @State private var scrollCommit: DispatchWorkItem?

    var body: some View {
        let displayedValue = trackedValue ?? value
        VStack(spacing: 3) {
            HStack(spacing: 8) {
                Image(systemName: displayedValue == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                Text("\(Int(displayedValue.rounded()))%")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
                    .accessibilityLabel("Output volume")
                    .accessibilityValue("\(Int(displayedValue.rounded())) percent")
                GeometryReader { geo in
                    let width = geo.size.width
                    let fraction = min(max(displayedValue / maxPercent, 0), 1)
                    let hundred = min(100 / maxPercent, 1)
                    let knobX = sliderPosition(for: fraction, width: width)
                    let hundredX = sliderPosition(for: hundred, width: width)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.12)).frame(height: 5)
                        Capsule().fill(Color.accentColor)
                            .frame(width: displayedValue > 0 ? min(knobX, hundredX) : 0, height: 5)
                        if displayedValue > 100 {
                            Rectangle().fill(.orange)
                                .frame(width: max(knobX - hundredX, 0), height: 5)
                                .offset(x: hundredX)
                        }
                        // 100 % tick.
                        if maxPercent > 100 {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.primary.opacity(0.35))
                                .frame(width: 2, height: 9)
                                .offset(x: hundredX - 1)
                        }
                        Circle()
                            .fill(.white)
                            .frame(width: knobDiameter, height: knobDiameter)
                            .shadow(color: .black.opacity(0.35), radius: 1.5, y: 0.5)
                            .offset(x: knobX - knobDiameter / 2)
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let updated = sliderValue(at: gesture.location.x, width: width)
                            beginTrackingIfNeeded(at: updated)
                            trackedValue = updated
                            let now = ProcessInfo.processInfo.systemUptime
                            if lastPreviewTime == 0 {
                                previewInterval = DisplayRefreshRate.interval()
                            }
                            if lastPreviewTime == 0 || now - lastPreviewTime >= previewInterval {
                                onPreview(updated)
                                lastPreviewTime = now
                            }
                        }
                        .onEnded { gesture in
                            let updated = sliderValue(at: gesture.location.x, width: width)
                            finishTracking(at: updated)
                        })
                    .overlay {
                        ScrollWheelMonitor { deltaY, isPrecise in
                            adjustFromScroll(deltaY: deltaY, isPrecise: isPrecise)
                        }
                    }
                }
                .frame(height: 18)
            }
            GeometryReader { geo in
                let width = geo.size.width
                let hundred = min(100 / maxPercent, 1)
                ZStack(alignment: .topLeading) {
                    Text("0%")
                        .position(x: sliderPosition(for: 0, width: width), y: 5)
                    if maxPercent > 100 {
                        Text("100%")
                            .position(x: sliderPosition(for: hundred, width: width), y: 5)
                    }
                    Text("\(Int(maxPercent))%")
                        .position(x: sliderPosition(for: 1, width: width), y: 5)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(height: 11)
            // Match the icon + spacing + fixed percentage field + spacing
            // above so 0%, 100%, and max stay under the actual track.
            .padding(.leading, 68)
        }
        .onDisappear {
            if let trackedValue { finishTracking(at: trackedValue) }
        }
    }

    private func sliderValue(at x: CGFloat, width: CGFloat) -> Double {
        guard width > knobDiameter else { return value }
        return min(max(Double((x - knobDiameter / 2) / (width - knobDiameter)) * maxPercent, 0), maxPercent)
    }

    private func sliderPosition(for fraction: Double, width: CGFloat) -> CGFloat {
        knobDiameter / 2 + CGFloat(fraction) * max(width - knobDiameter, 0)
    }

    private func beginTrackingIfNeeded(at currentValue: Double) {
        guard trackedValue == nil else { return }
        trackedValue = currentValue
        onEditingChanged(true)
    }

    private func finishTracking(at finalValue: Double) {
        scrollCommit?.cancel()
        scrollCommit = nil
        onPreview(finalValue)
        value = finalValue
        trackedValue = nil
        lastPreviewTime = 0
        onEditingChanged(false)
    }

    private func adjustFromScroll(deltaY: CGFloat, isPrecise: Bool) {
        let currentValue = trackedValue ?? value
        let updated = Self.valueAfterScroll(
            currentValue, deltaY: deltaY, isPrecise: isPrecise, maxPercent: maxPercent
        )
        guard updated != currentValue else { return }

        beginTrackingIfNeeded(at: currentValue)
        trackedValue = updated
        onPreview(updated)

        scrollCommit?.cancel()
        let work = DispatchWorkItem { finishTracking(at: updated) }
        scrollCommit = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    static func valueAfterScroll(_ currentValue: Double, deltaY: CGFloat,
                                 isPrecise: Bool, maxPercent: Double) -> Double {
        let pointsPerUnit = isPrecise ? 0.2 : 2.0
        return min(max(currentValue + Double(deltaY) * pointsPerUnit, 0), maxPercent)
    }
}

/// Observes scroll-wheel events over the slider without taking hit-testing
/// away from SwiftUI's drag gesture.
private struct ScrollWheelMonitor: NSViewRepresentable {
    var onScroll: (_ deltaY: CGFloat, _ isPrecise: Bool) -> Void

    func makeNSView(context: Context) -> ScrollWheelMonitoringView {
        ScrollWheelMonitoringView(onScroll: onScroll)
    }

    func updateNSView(_ view: ScrollWheelMonitoringView, context: Context) {
        view.onScroll = onScroll
    }
}

@MainActor
private final class ScrollWheelMonitoringView: NSView {
    var onScroll: (_ deltaY: CGFloat, _ isPrecise: Bool) -> Void
    private var eventMonitor: Any?

    init(onScroll: @escaping (_ deltaY: CGFloat, _ isPrecise: Bool) -> Void) {
        self.onScroll = onScroll
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removeEventMonitor()
        } else if eventMonitor == nil {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, event.window === self.window else { return event }
                let location = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(location), event.scrollingDeltaY != 0 else { return event }
                self.onScroll(event.scrollingDeltaY, event.hasPreciseScrollingDeltas)
                return nil
            }
        }
    }

    private func removeEventMonitor() {
        guard let eventMonitor else { return }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }

    deinit {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
    }
}

enum PermissionHelper {
    static func openSystemSettings() {
        // Privacy & Security → Screen & System Audio Recording.
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture")!
        NSWorkspace.shared.open(url)
    }
}
