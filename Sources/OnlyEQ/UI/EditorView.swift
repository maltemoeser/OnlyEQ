import SwiftUI
import Combine
import AppKit
import QuartzCore

private struct ImportPresentation: Identifiable {
    let id = UUID()
    var profileSuggestion: ProfileSuggestion?
}

/// The EQ editor window: toolbar, interactive graph, band strip, bottom bar.
struct EditorView: View {
    static let importRequested = PassthroughSubject<ProfileSuggestion?, Never>()

    var initialImportRequested = false
    var initialProfileSuggestion: ProfileSuggestion?

    @EnvironmentObject var state: AppState
    @Environment(\.undoManager) private var undoManager
    @State private var selectedBandID: UUID?
    @State private var importPresentation: ImportPresentation?
    @State private var showSaveSheet = false
    @State private var saveName = ""
    @State private var handledInitialImport = false
    /// The preset as it was when a node drag began; one undo step per drag.
    @State private var dragStartPreset: EQPreset?

    var body: some View {
        VStack(spacing: 0) {
            if state.editorShowsSettings {
                settingsBar
                Divider()
                SettingsView()
            } else {
                toolbar
                Divider()
                graph
                bandStrip
                Divider()
                bottomBar
            }
        }
        .sheet(item: $importPresentation) { presentation in
            ImportSheet(profileSuggestion: presentation.profileSuggestion).environmentObject(state)
        }
        .sheet(isPresented: $showSaveSheet) { saveSheet }
        .onDeleteCommand { deleteSelectedBand() }
        .onReceive(Self.importRequested) { suggestion in
            importPresentation = ImportPresentation(profileSuggestion: suggestion)
        }
        .onAppear {
            guard initialImportRequested, !handledInitialImport else { return }
            handledInitialImport = true
            importPresentation = ImportPresentation(profileSuggestion: initialProfileSuggestion)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(state.store.allPresets) { preset in
                    Button(preset.name) {
                        state.recordingUndo("Switch Preset", undoManager) { state.apply(preset) }
                    }
                }
                if let stored = state.savedPreset, state.store.customPresets.contains(stored) {
                    Divider()
                    Button("Delete “\(stored.name)”…", role: .destructive) {
                        WindowManager.shared.confirmDeletePreset(stored)
                    }
                }
            } label: {
                Text(state.preset.name).font(.callout.weight(.medium)).lineLimit(1)
            }
            .frame(maxWidth: 220)

            Button("Save…") {
                saveName = state.preset.name
                showSaveSheet = true
            }
            .keyboardShortcut("s", modifiers: .command)
            .help("Save the current curve as a preset")

            Button("Revert") {
                state.recordingUndo("Revert", undoManager) { state.revertPreset() }
            }
                .disabled(!state.presetIsModified)
                .help("Discard edits and return to the saved preset")

            Spacer()

            Picker("", selection: Binding(
                get: { state.abSlot },
                set: { state.storeABAndSwitch(to: $0) }
            )) {
                Text("A").tag(0)
                Text("B").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 90)
            .help("Compare two versions. Switching stores the current curve in the slot you leave.")

            Toggle("Bypass", isOn: $state.bypassed)
                .toggleStyle(.button)

            Spacer()

            Button {
                importPresentation = ImportPresentation(profileSuggestion: nil)
            } label: {
                Label("Import…", systemImage: "square.and.arrow.down")
            }

            Button {
                state.editorShowsSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
            .help("Settings")
            .accessibilityLabel("Settings")
        }
        .controlSize(.small)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    private var settingsBar: some View {
        HStack {
            Button {
                state.editorShowsSettings = false
            } label: {
                Label("Equalizer", systemImage: "chevron.left")
            }
            .keyboardShortcut(.cancelAction)
            Spacer()
            Text("Settings").font(.callout.weight(.semibold))
            Spacer()
            // Balances the leading button so the title stays centred.
            Label("Equalizer", systemImage: "chevron.left").hidden()
        }
        .controlSize(.small)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Graph

    private var graph: some View {
        VStack(spacing: 3) {
            // The graph shows the EQ shape only — preamp is gain staging,
            // shown in the bottom bar, not baked into the curve.
            EQCurveView(
                bands: state.preset.bands,
                preampDB: 0,
                interactive: true,
                showSpectrum: state.isEnabled && state.editorIsVisible,
                showIndividualCurves: true,
                rangeDB: state.preset.displayRangeDB,
                selectedBandID: $selectedBandID,
                onBandChange: { id, f, g in
                    guard let i = state.preset.bands.firstIndex(where: { $0.id == id }) else { return }
                    if dragStartPreset == nil { dragStartPreset = state.preset }
                    state.preset.bands[i].frequency = f
                    state.preset.bands[i].gain = g
                },
                onBandDragEnded: {
                    if let before = dragStartPreset, before != state.preset {
                        state.registerUndo(restoring: before, actionName: "Move Band", undoManager: undoManager)
                    }
                    dragStartPreset = nil
                    state.flushWorkingPresetPersistence()
                },
                onAddBand: { f, g in
                    addBand(EQBand(type: .peak, frequency: f, gain: g, q: 1.41))
                }
            )
            .frame(minHeight: 220, maxHeight: .infinity)
            .opacity(state.bypassed ? 0.45 : 1)
            .animation(.easeInOut(duration: 0.15), value: state.bypassed)
            .overlay(alignment: .topLeading) {
                Text("+\(Int(state.preset.displayRangeDB)) dB").font(.caption2).foregroundStyle(.secondary).padding(4)
            }
            .overlay(alignment: .bottomLeading) {
                Text("−\(Int(state.preset.displayRangeDB)) dB").font(.caption2).foregroundStyle(.secondary).padding(4)
            }
            .overlay(alignment: .bottomTrailing) {
                if state.isEnabled && !state.bypassed {
                    spectrumLegend
                }
            }
            .overlay(alignment: .topTrailing) {
                if state.bypassed {
                    Label("Bypassed", systemImage: "eye.slash")
                        .font(.caption.weight(.medium)).foregroundStyle(.secondary).padding(4)
                } else {
                    Label("Double-click graph to add band", systemImage: "plus.circle")
                        .font(.caption).foregroundStyle(.tertiary).padding(4)
                }
            }
            FrequencyAxisLabels()
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
    }

    /// Names the two spectra: grey is what comes in, accent is what goes out.
    private var spectrumLegend: some View {
        HStack(spacing: 10) {
            legendItem("Input", color: .secondary.opacity(0.6))
            legendItem("Output", color: Color.accentColor)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(4)
        .help("Grey bars show the audio before EQ; accent bars show it after.")
        .accessibilityElement(children: .combine)
    }

    private func legendItem(_ title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 7, height: 7)
            Text(title)
        }
    }

    // MARK: - Band strip

    private var bandStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(state.preset.bands.enumerated()), id: \.element.id) { index, band in
                    BandCard(index: index, band: bandBinding(band.id),
                             isSelected: selectedBandID == band.id,
                             onDelete: { deleteBand(band.id) })
                        .onTapGesture { selectedBandID = band.id }
                }
                Button {
                    addBand(EQBand(type: .peak, frequency: 1000, gain: 0, q: 1.41))
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                        .frame(width: 44, height: 100)
                }
                .buttonStyle(.plain)
                .help("Add band")
                .accessibilityLabel("Add band")
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.tertiary)
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .frame(height: 122)
    }

    private func bandBinding(_ id: UUID) -> Binding<EQBand> {
        Binding(
            get: { state.preset.bands.first { $0.id == id } ?? EQBand() },
            set: { newValue in
                guard let i = state.preset.bands.firstIndex(where: { $0.id == id }) else { return }
                state.recordingUndo("Edit Band", undoManager) { state.preset.bands[i] = newValue }
            }
        )
    }

    private func addBand(_ band: EQBand) {
        guard state.preset.bands.count < 32 else { return }
        state.recordingUndo("Add Band", undoManager) { state.preset.bands.append(band) }
        selectedBandID = band.id
    }

    private func deleteBand(_ id: UUID) {
        state.recordingUndo("Delete Band", undoManager) {
            state.preset.bands.removeAll { $0.id == id }
        }
        if selectedBandID == id { selectedBandID = nil }
    }

    private func deleteSelectedBand() {
        guard let id = selectedBandID else { return }
        deleteBand(id)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Text("Preamp")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
            ManualPreampControl(
                value: Binding(
                    get: { state.preset.preampDB },
                    set: { value in
                        state.recordingUndo("Change Preamp", undoManager) { state.preset.preampDB = value }
                    }
                ),
                effectiveValue: state.effectivePreampDB,
                isDisabled: state.autoPreampEnabled,
                onPreview: { state.previewManualPreampDB($0) }
            )
            Toggle("Auto", isOn: $state.autoPreampEnabled)
                .toggleStyle(.checkbox)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
            clipIndicator
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
            Spacer()
        }
        .controlSize(.small)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    private var clipIndicator: some View {
        PeakMeterView(processor: state.engine.processor, isActive: state.editorIsVisible)
            .frame(width: 78, height: 14)
    }

    /// A stored custom preset, other than the one being edited, that the typed
    /// name would replace. Saving over the current preset's own name is a plain
    /// save and warns nothing.
    private var presetReplacedBySave: EQPreset? {
        let name = saveName.trimmingCharacters(in: .whitespaces)
        return state.store.customPresets.first { $0.name == name && $0.id != state.preset.id }
    }

    private var saveSheet: some View {
        VStack(spacing: 12) {
            Text("Save Preset").font(.headline)
            TextField("Preset name", text: $saveName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
            if presetReplacedBySave != nil {
                Label("A preset with this name exists and will be replaced.",
                      systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 240, alignment: .leading)
            }
            HStack {
                Button("Cancel") { showSaveSheet = false }
                Button(presetReplacedBySave == nil ? "Save" : "Replace") {
                    state.saveCurrentAsPreset(named: saveName.trimmingCharacters(in: .whitespaces))
                    showSaveSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(saveName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
    }
}

/// Keeps manual-preamp tracking local so the rest of the editor only observes
/// the single committed preset change at drag end.
private struct ManualPreampControl: View {
    @Binding var value: Double
    var effectiveValue: Double
    var isDisabled: Bool
    var onPreview: (Double) -> Void
    @State private var trackedValue: Double?

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%.1f dB", trackedValue ?? effectiveValue))
                .font(.subheadline.weight(.medium).monospacedDigit())
                .frame(width: 52, alignment: .trailing)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
            Slider(
                value: Binding(
                    get: { trackedValue ?? value },
                    set: { updated in
                        let rounded = (updated * 10).rounded() / 10
                        trackedValue = rounded
                        onPreview(rounded)
                    }
                ),
                in: -20...0,
                onEditingChanged: { editing in
                    if !editing { commitTrackedValue() }
                }
            )
            .frame(minWidth: 72, idealWidth: 150, maxWidth: 160)
            .disabled(isDisabled)
        }
        .onDisappear { commitTrackedValue() }
    }

    private func commitTrackedValue() {
        guard let trackedValue else { return }
        value = trackedValue
        self.trackedValue = nil
    }
}

/// Keeps the display-linked peak readout out of SwiftUI's view graph. Updating this
/// AppKit view redraws only its 78×14-point bounds instead of the editor.
private struct PeakMeterView: NSViewRepresentable {
    let processor: EQProcessor
    let isActive: Bool

    func makeNSView(context: Context) -> PeakMeterNSView {
        let view = PeakMeterNSView(processor: processor)
        view.setActive(isActive)
        return view
    }

    func updateNSView(_ view: PeakMeterNSView, context: Context) {
        view.setActive(isActive)
    }

    static func dismantleNSView(_ view: PeakMeterNSView, coordinator: ()) {
        view.stopAnimating()
    }
}

@MainActor
private final class PeakMeterNSView: NSView {
    private let processor: EQProcessor
    private let dotLayer = CAShapeLayer()
    private let textLayer = CATextLayer()
    private var animationLink: CADisplayLink?
    private var active = false
    private var db: Double = -60
    private var renderedLabel = ""
    private var renderedColor: NSColor?

    init(processor: EQProcessor) {
        self.processor = processor
        super.init(frame: .zero)
        wantsLayer = true
        dotLayer.actions = ["path": NSNull(), "fillColor": NSNull()]
        textLayer.actions = ["string": NSNull(), "foregroundColor": NSNull(),
                             "bounds": NSNull(), "position": NSNull()]
        let pointSize = NSFont.preferredFont(forTextStyle: .caption1).pointSize
        textLayer.font = NSFont.monospacedDigitSystemFont(ofSize: pointSize, weight: .regular)
        textLayer.fontSize = pointSize
        textLayer.alignmentMode = .left
        layer?.addSublayer(dotLayer)
        layer?.addSublayer(textLayer)
        updateLayers(force: true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dotLayer.path = CGPath(ellipseIn: CGRect(x: 0, y: max((bounds.height - 7) / 2, 0),
                                                 width: 7, height: 7), transform: nil)
        textLayer.frame = CGRect(x: 11, y: 0, width: max(bounds.width - 11, 0), height: bounds.height)
        textLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        CATransaction.commit()
    }

    func setActive(_ active: Bool) {
        guard self.active != active else { return }
        self.active = active
        if active, window != nil {
            startAnimating()
        } else {
            stopAnimating()
            db = -60
            updateLayers(force: true)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if active, window != nil { startAnimating() } else { stopAnimating() }
    }

    private func updateLayers(force: Bool = false) {
        let color: NSColor = db > -0.1 ? .systemRed : (db > -3 ? .systemOrange : .systemGreen)
        let label = String(format: "%.1f dBFS", max(db, -60))
        guard force || label != renderedLabel || color != renderedColor else { return }
        renderedLabel = label
        renderedColor = color

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dotLayer.fillColor = color.cgColor
        textLayer.string = label
        textLayer.foregroundColor = NSColor.secondaryLabelColor.cgColor
        CATransaction.commit()
    }

    func stopAnimating() {
        animationLink?.invalidate()
        animationLink = nil
    }

    private func startAnimating() {
        guard animationLink == nil else { return }
        let link = displayLink(target: self, selector: #selector(samplePeak(_:)))
        DisplayRefreshRate.configure(link, for: window)
        link.add(to: .main, forMode: .common)
        animationLink = link
        samplePeak(link)
    }

    @objc private func samplePeak(_ link: CADisplayLink) {
        let peak = processor.currentPeak
        db = peak > 0 ? 20 * log10(Double(peak)) : -60
        updateLayers()
    }

    deinit {
        animationLink?.invalidate()
    }
}

/// Compact per-band card: color dot, type menu, Fc/Gain/Q fields, delete.
struct BandCard: View {
    var index: Int
    @Binding var band: EQBand
    var isSelected: Bool
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(BandPalette.color(index)).frame(width: 8, height: 8)
                Text("\(index + 1)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Menu {
                    ForEach(FilterType.allCases) { type in
                        Button(type.displayName) { band.type = type }
                    }
                } label: {
                    Text(band.type.displayName).font(.caption)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer(minLength: 0)
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .help("Delete band")
                .accessibilityLabel("Delete band")
            }
            valueRow("Fc", value: $band.frequency, range: 20...20000, format: freqFormat, parse: parseFreq)
            valueRow("Gain", value: $band.gain, range: -30...30, format: { String(format: "%.1f dB", $0) },
                     parse: { Double($0.replacingOccurrences(of: "dB", with: "").trimmingCharacters(in: .whitespaces)) })
            valueRow("Q", value: $band.q, range: 0.1...30, format: { String(format: "%.2f", $0) }, parse: { Double($0) })
        }
        .padding(8)
        .frame(width: 150)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? BandPalette.color(index) : Color(nsColor: .separatorColor),
                                      lineWidth: isSelected ? 1.5 : 1)
                )
        )
        .opacity(band.isEnabled ? 1 : 0.5)
        .contextMenu {
            Button(band.isEnabled ? "Disable Band" : "Enable Band") { band.isEnabled.toggle() }
            Button("Delete Band", role: .destructive) { onDelete() }
        }
    }

    private func freqFormat(_ f: Double) -> String {
        f >= 1000 ? String(format: "%.1f kHz", f / 1000) : String(format: "%.0f Hz", f)
    }

    private func parseFreq(_ s: String) -> Double? {
        var cleaned = s.lowercased().replacingOccurrences(of: "hz", with: "").trimmingCharacters(in: .whitespaces)
        var multiplier = 1.0
        if cleaned.hasSuffix("k") {
            cleaned = String(cleaned.dropLast()).trimmingCharacters(in: .whitespaces)
            multiplier = 1000
        }
        return Double(cleaned).map { $0 * multiplier }
    }

    /// Typed values are clamped to the same range the canvas drag allows, so a
    /// stray "0" cannot put a node at log10(0) or push gain off the graph.
    private func valueRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>,
                          format: @escaping (Double) -> String,
                          parse: @escaping (String) -> Double?) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary).frame(width: 28, alignment: .leading)
            // The draft carries the exact unitless value so a band shown as
            // "1.5 kHz" edits as "1534", not "1.5" (which would parse as 1.5 Hz).
            EditableValueField(label: label, text: format(value.wrappedValue),
                               editText: String(format: "%g", value.wrappedValue)) { input in
                if let parsed = parse(input), parsed.isFinite {
                    value.wrappedValue = min(max(parsed, range.lowerBound), range.upperBound)
                }
            }
        }
    }
}

/// A tiny click-to-edit text field for band values. The resting state is a
/// button, so the value can be reached by keyboard and read by VoiceOver.
struct EditableValueField: View {
    var label: String
    var text: String
    var editText: String
    var onCommit: (String) -> Void

    @State private var editing = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        if editing {
            TextField(label, text: $draft, onCommit: {
                onCommit(draft)
                editing = false
            })
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .font(.caption.monospacedDigit())
            .frame(height: 18)
            .focused($fieldFocused)
            .onAppear { fieldFocused = true }
            .onExitCommand { editing = false }
        } else {
            Button {
                draft = editText
                editing = true
            } label: {
                Text(text)
                    .font(.caption.monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.vertical, 2).padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(.quaternary.opacity(0.5)))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityValue(text)
            .accessibilityHint("Edit")
        }
    }
}
