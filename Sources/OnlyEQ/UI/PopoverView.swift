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
// STORY: Open, watch the music move under the curve, see which preset and
//   device are live, flip Bypass to hear it flat, close. Editing happens
//   elsewhere.
// FIRST VIEWPORT: 360 pt wide, about 400 tall. OnlyEQ, its latency in
//   small type, and its switch; the plot, 150 pt, with the live spectrum
//   leading and the curve a line over it, a vertical volume fader at its
//   side, and a pill in the corner only when something is off (bypassed,
//   waiting, error); Bypass and Crossfeed as small capsule toggles under the
//   axis with the output device as a text capsule pull-down at the row's end;
//   the preset with its "use automatically" checkbox; a hairline, then a
//   bordered Open Equalizer… and the gear.
// FORM: curve-first stack, candidate 2 of the grounded list, chosen by the
//   user over the rolled candidate 7 (key 1512465f).
// FINISH: unreviewed and undocumented is unfinished; this build ends with
//   the finish review, the verdict, and DESIGN.md.

/// Main menu-bar popover: name and switch, the live curve, the listening
/// row with the output device, then the preset.
struct PopoverView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("showLatency") private var showLatency = true

    static let width: CGFloat = 360
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
                presetRow
                    .padding(.top, 18)
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
        .onExitCommand {
            NotificationCenter.default.post(name: .onlyEQHideMenuPanel, object: nil)
        }
    }

    // MARK: - Curve pane

    private var curvePane: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    if state.suspectedPermissionIssue {
                        permissionNotice
                    } else {
                        curveButton
                        if let status = exceptionalStatus {
                            statusPill(status)
                                .padding(8)
                        }
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
            // Volume as a fader beside the plot: the track matches the
            // well's height and the readout sits on the axis line.
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
            .frame(height: Self.plotHeight + 16)
            .disabled(!state.isEnabled)
        }
        .opacity(state.isEnabled ? 1 : 0.45)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: state.isEnabled)
    }

    private var curveButton: some View {
        Button {
            WindowManager.shared.showEditor()
        } label: {
            // The spectrum leads and the curve is a line over it. Bypass
            // settles the line onto 0 dB rather than blanking it: the one
            // authored moment, and it says what bypass does.
            EQCurveView(bands: state.preset.bands, preampDB: 0,
                        showSpectrum: state.isEnabled && state.popoverIsVisible,
                        spectrumStyle: .live, curveStyle: .line,
                        rangeDB: state.preset.displayRangeDB,
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

    /// The pill names only what the switch cannot: bypassed, waiting for
    /// audio, or failed. Plain running is the switch being on.
    private var exceptionalStatus: (text: String, color: Color)? {
        guard state.isEnabled else { return nil }
        switch state.engineState {
        case .running:
            if state.suspectedPermissionIssue { return ("Waiting for audio", .orange) }
            return state.bypassed ? ("Bypassed", .secondary) : nil
        case .stopped: return nil
        case .failed: return ("Error", .red)
        }
    }

    private func statusPill(_ status: (text: String, color: Color)) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
            Text(status.text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(.background.opacity(0.6)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status")
        .accessibilityValue(status.text)
    }

    /// Processing latency, a detail beside the name while the EQ runs.
    private var latencyDetail: String? {
        guard showLatency, state.isEnabled, !state.suspectedPermissionIssue,
              case .running = state.engineState else { return nil }
        return "\(state.latencyMilliseconds) ms"
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
            if let latency = latencyDetail {
                Text(latency)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .help("Latency the EQ adds to the output")
                    .accessibilityLabel("Latency \(latency)")
            }
            Spacer()
            Toggle("", isOn: $state.isEnabled)
                .toggleStyle(AccentSwitchStyle())
                .labelsHidden()
                .accessibilityLabel("Enable EQ")
        }
    }

    /// The preset leads: it is what this app adds. Its binding sits under it.
    private var presetRow: some View {
        IdentityRow(symbol: "waveform.path", symbolLabel: "Preset") {
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
                menuLabel(state.preset.name, weight: .semibold)
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

    /// The output device as a capsule pull-down at the row's trailing end:
    /// where the sound goes, beside the switches that shape it.
    private var deviceMenu: some View {
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
            Text(state.currentDevice?.name ?? "No Output Device")
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .menuStyle(.button)
        .help("Output device")
        .accessibilityLabel("Output device")
        .accessibilityValue(state.currentDevice?.name ?? "No Output Device")
    }

    /// The listening switches sit under the curve as capsules, kin to the
    /// status pill: Bypass settles the curve when pressed, so the control
    /// and its feedback stay together. The device pull-down closes the row.
    private var listeningRow: some View {
        HStack(spacing: 6) {
            Toggle("Bypass", isOn: $state.bypassed)
                .help("Hear the unprocessed signal without changing the preset")
            Toggle("Crossfeed", isOn: $state.crossfeedEnabled)
                .help("Blend a little of each channel into the other for headphones")
            Spacer(minLength: 6)
            deviceMenu
                .layoutPriority(-1)
        }
        .toggleStyle(.button)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
    }

    private func menuLabel(_ name: String, weight: Font.Weight) -> some View {
        Text(name)
            .font(.body.weight(weight))
            .lineLimit(1)
            .truncationMode(.middle)
    }

    // MARK: - Footer

    /// A hairline, then the way into the editor as a real button: the other
    /// half of the app.
    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 6) {
                Button("Open Equalizer…") {
                    WindowManager.shared.showEditor()
                }
                .buttonStyle(.bordered)
                Spacer(minLength: 0)
                AppGearMenu()
                    .menuStyle(.borderlessButton)
                    .fixedSize()
            }
            .padding(.top, 10)
        }
    }
}

/// Vertical volume fader beside the plot: accent to 100 %, orange boost zone
/// above it, a tick at 100 %. The track spans the plot's full height so the
/// knob reaches the plot's top line; the readout sits below on the axis
/// line and turns orange in the boost zone.
struct BoostSlider: View {
    @Binding var value: Double
    var maxPercent: Double
    var onPreview: (Double) -> Void = { _ in }
    var onEditingChanged: (_ editing: Bool) -> Void = { _ in }
    static let width: CGFloat = 30
    private let knobDiameter: CGFloat = 13
    @State private var trackedValue: Double?
    @State private var lastPreviewTime: TimeInterval = 0
    @State private var previewInterval: TimeInterval = 1.0 / 60.0
    @State private var scrollCommit: DispatchWorkItem?

    var body: some View {
        let displayedValue = trackedValue ?? value
        let percent = Int(displayedValue.rounded())
        VStack(spacing: 4) {
            GeometryReader { geo in
                let height = geo.size.height
                let fraction = min(max(displayedValue / maxPercent, 0), 1)
                let hundred = min(100 / maxPercent, 1)
                let knobY = faderPosition(for: fraction, height: height)
                let hundredY = faderPosition(for: hundred, height: height)
                ZStack(alignment: .bottom) {
                    Capsule().fill(Color.primary.opacity(0.12)).frame(width: 4)
                    Capsule().fill(Color.accentColor)
                        .frame(width: 4, height: displayedValue > 0 ? min(knobY, hundredY) : 0)
                    if displayedValue > 100 {
                        Rectangle().fill(.orange)
                            .frame(width: 4, height: max(knobY - hundredY, 0))
                            .offset(y: -hundredY)
                    }
                    // 100 % tick.
                    if maxPercent > 100 {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.primary.opacity(0.35))
                            .frame(width: 8, height: 2)
                            .offset(y: -(hundredY - 1))
                    }
                    Circle()
                        .fill(.white)
                        .frame(width: knobDiameter, height: knobDiameter)
                        .shadow(color: .black.opacity(0.35), radius: 1.5, y: 0.5)
                        .offset(y: -(knobY - knobDiameter / 2))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let updated = faderValue(at: gesture.location.y, height: height)
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
                        let updated = faderValue(at: gesture.location.y, height: height)
                        finishTracking(at: updated)
                    })
                .overlay {
                    ScrollWheelMonitor { deltaY, isPrecise in
                        adjustFromScroll(deltaY: deltaY, isPrecise: isPrecise)
                    }
                }
            }
            Text(displayedValue == 0 ? "Off" : "\(percent)%")
                .font(.caption2.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(displayedValue > 100 ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                .frame(height: 12)
        }
        .frame(width: Self.width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Output volume")
        .accessibilityValue("\(percent) percent")
        .accessibilityAdjustableAction { direction in
            let step: Double = direction == .increment ? 5 : -5
            finishTracking(at: min(max(displayedValue + step, 0), maxPercent))
        }
        .help("Output volume, \(percent) %")
        .onDisappear {
            if let trackedValue { finishTracking(at: trackedValue) }
        }
    }

    /// Bottom of the track is 0, the top is the maximum.
    private func faderValue(at y: CGFloat, height: CGFloat) -> Double {
        guard height > knobDiameter else { return value }
        let fromBottom = height - y
        return min(max(Double((fromBottom - knobDiameter / 2) / (height - knobDiameter)) * maxPercent, 0), maxPercent)
    }

    private func faderPosition(for fraction: Double, height: CGFloat) -> CGFloat {
        knobDiameter / 2 + CGFloat(fraction) * max(height - knobDiameter, 0)
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
