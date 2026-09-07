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
// FIRST VIEWPORT: 360 pt wide, about 400 tall. OnlyEQ and its switch; the
//   plot, 150 pt, with its axis and a status pill in the corner; Bypass and
//   Crossfeed as small toggles under the axis; output device with
//   volume; preset with its "use automatically" checkbox; a hairline, then
//   Open Equalizer… and the gear. The plot is the only bordered surface and
//   the toggles the only bordered controls: everything else is text.
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
    static let minHeight: CGFloat = 380
    static let cornerRadius: CGFloat = 14
    static let plotHeight: CGFloat = 150

    var body: some View {
        // Rhythm: tight inside a group (plot to axis to toggles), generous
        // between groups, so the eye lands on the curve, then the rows.
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 10)
            curvePane
            Group {
                listeningRow
                    .padding(.top, 8)
                deviceRow
                    .padding(.top, 20)
                presetRow
                    .padding(.top, 16)
            }
            .disabled(!state.isEnabled)
            .opacity(state.isEnabled ? 1 : 0.45)
            footer
                .padding(.top, 14)
        }
        .padding(.top, 14)
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
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
            // Bypass settles the curve onto 0 dB rather than blanking it:
            // the one authored moment, and it says what bypass does.
            EQCurveView(bands: state.preset.bands, preampDB: 0,
                        showSpectrum: state.isEnabled && state.popoverIsVisible,
                        spectrumStyle: .normal, rangeDB: state.preset.displayRangeDB,
                        responseScale: state.bypassed ? 0 : 1)
                .padding(.vertical, 1)
                .opacity(state.bypassed ? 0.55 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: state.bypassed)
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
            Spacer(minLength: 6)
            // Volume mostly comes from the keyboard, so the slider is a
            // small trailing control, not a second line.
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
        } detail: {
            EmptyView()
        }
    }

    private var presetRow: some View {
        IdentityRow(symbol: "slider.horizontal.3", symbolLabel: "Preset") {
            Menu {
                ForEach(state.store.allPresets) { preset in
                    Button(preset.name) { state.apply(preset) }
                }
                Divider()
                Button("Import Preset…") {
                    WindowManager.shared.showEditor(importing: true)
                }
                if let stored = state.savedPreset, state.store.customPresets.contains(stored) {
                    Button("Delete “\(stored.name)”…", role: .destructive) {
                        WindowManager.shared.confirmDeletePreset(stored)
                    }
                }
            } label: {
                menuLabel(state.preset.name)
            }
            .menuStyle(.borderlessButton)
            .fixedSize(horizontal: false, vertical: true)
            .help("Preset")
        } detail: {
            // The binding that makes "set once" work is otherwise invisible;
            // one checkbox both makes it and undoes it.
            Toggle(isOn: presetBinding) {
                Text(state.currentDevice.map { "Use automatically on \($0.name)" }
                     ?? "Use automatically on this device")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .disabled(state.currentDevice == nil)
            .help("Apply this preset whenever this device becomes the output")
        }
    }

    private var presetBinding: Binding<Bool> {
        Binding(
            get: {
                guard let device = state.currentDevice,
                      let profile = state.store.deviceProfiles[device.uid] else { return false }
                return profile.autoApply && state.presetIsBoundToCurrentDevice
            },
            set: { on in
                if on { state.bindPresetToCurrentDevice() } else { state.unbindCurrentDevice() }
            }
        )
    }

    /// The listening switches sit under the curve: Bypass empties the
    /// plot when pressed, so the control and its feedback stay together.
    private var listeningRow: some View {
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

    private func menuLabel(_ name: String) -> some View {
        Text(name)
            .font(.body.weight(.medium))
            .lineLimit(1)
            .truncationMode(.middle)
    }

    // MARK: - Footer

    /// A hairline and a plain text button, the way Control Center modules
    /// end in "Sound Settings…".
    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 6) {
                Button("Open Equalizer…") {
                    WindowManager.shared.showEditor()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                Spacer(minLength: 0)
                AppGearMenu()
                    .menuStyle(.borderlessButton)
                    .fixedSize()
            }
            .padding(.top, 8)
        }
    }
}

/// Volume slider: accent track to 100 %, orange boost zone beyond, tick at
/// 100 %; the readout turns orange in the boost zone.
struct BoostSlider: View {
    @Binding var value: Double
    var maxPercent: Double
    var onPreview: (Double) -> Void = { _ in }
    var onEditingChanged: (_ editing: Bool) -> Void = { _ in }
    private let knobDiameter: CGFloat = 13
    private let trackWidth: CGFloat = 84
    @State private var trackedValue: Double?
    @State private var lastPreviewTime: TimeInterval = 0
    @State private var previewInterval: TimeInterval = 1.0 / 60.0
    @State private var scrollCommit: DispatchWorkItem?

    var body: some View {
        let displayedValue = trackedValue ?? value
        HStack(spacing: 5) {
            // The number appears while the value is changing, and stays
            // while the output is boosted past 100 %.
            if trackedValue != nil || displayedValue > 100 {
                Text("\(Int(displayedValue.rounded()))%")
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(displayedValue > 100 ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                    .frame(width: 28, alignment: .trailing)
                    .accessibilityHidden(true)
            }
            Image(systemName: displayedValue == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 13)
                .accessibilityHidden(true)
            GeometryReader { geo in
                let width = geo.size.width
                let fraction = min(max(displayedValue / maxPercent, 0), 1)
                let hundred = min(100 / maxPercent, 1)
                let knobX = sliderPosition(for: fraction, width: width)
                let hundredX = sliderPosition(for: hundred, width: width)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12)).frame(height: 4)
                    Capsule().fill(Color.accentColor)
                        .frame(width: displayedValue > 0 ? min(knobX, hundredX) : 0, height: 4)
                    if displayedValue > 100 {
                        Rectangle().fill(.orange)
                            .frame(width: max(knobX - hundredX, 0), height: 4)
                            .offset(x: hundredX)
                    }
                    // 100 % tick.
                    if maxPercent > 100 {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.primary.opacity(0.35))
                            .frame(width: 2, height: 8)
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
            .frame(width: trackWidth, height: 16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Output volume")
        .accessibilityValue("\(Int(displayedValue.rounded())) percent")
        .help("Output volume, \(Int(displayedValue.rounded())) %")
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
