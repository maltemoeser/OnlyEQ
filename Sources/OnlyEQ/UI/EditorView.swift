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
    /// Draw the toolbar as a row inside the view instead of as window
    /// toolbar items; only the screenshot renderer wants this.
    var inlineToolbar = false

    @EnvironmentObject var state: AppState
    @Environment(\.undoManager) private var undoManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedBandID: UUID?
    @State private var selectedBandID: UUID?
    @State private var importPresentation: ImportPresentation?
    @State private var showSaveSheet = false
    @State private var saveName = ""
    @State private var handledInitialImport = false
    /// The preset as it was when a node drag began; one undo step per drag.
    @State private var dragStartPreset: EQPreset?
    /// The preset as it was when an Adjust slider drag began.
    @State private var adjustDragStart: EQPreset?

    var body: some View {
        VStack(spacing: 0) {
            if inlineToolbar {
                inlineToolbarRow
                Divider()
            }
            graph
            bandStrip.disabled(state.hearingReference)
            Divider()
            adjustBar.disabled(state.hearingReference)
            Divider()
            bottomBar
        }
        .navigationTitle(state.preset.name)
        .navigationSubtitle(state.presetIsModified ? "Edited" : "")
        .toolbar { if !inlineToolbar { windowToolbar } }
        .toolbarTitleMenu { presetMenuItems }
        .sheet(item: $importPresentation) { presentation in
            ImportSheet(profileSuggestion: presentation.profileSuggestion).environmentObject(state)
        }
        .sheet(isPresented: $showSaveSheet) { saveSheet }
        .onDeleteCommand { deleteSelectedBand() }
        .onMoveCommand { nudgeSelectedBand($0) }
        .onChange(of: focusedBandID) { _, id in
            if let id { selectedBandID = id }
        }
        .onReceive(Self.importRequested) { suggestion in
            importPresentation = ImportPresentation(profileSuggestion: suggestion)
        }
        .onAppear {
            guard initialImportRequested, !handledInitialImport else { return }
            handledInitialImport = true
            importPresentation = ImportPresentation(profileSuggestion: initialProfileSuggestion)
        }
    }

    // MARK: - Reference

    /// The curve kept aside to listen against. Clicking the pill hears it in
    /// place of the edit, level-matched; the chevron chooses or swaps it.
    @ViewBuilder
    private var referencePill: some View {
        if let reference = state.reference {
            Menu {
                referenceChoices
                Divider()
                Button("Swap with Reference") { state.swapWithReference(undoManager: undoManager) }
                Button("Clear Reference") { state.setReference(nil, undoManager: undoManager) }
            } label: {
                pillLabel(reference.name, hearing: state.hearingReference)
            } primaryAction: {
                state.hearingReference.toggle()
            }
            .menuStyle(.button)
            .buttonBorderShape(.capsule)
            .tint(state.hearingReference ? Color.accentColor : nil)
            .help(state.hearingReference
                  ? "Hearing the reference. Click to return to your edit."
                  : "Click to hear \(reference.name) in place of your edit, level-matched.")
            .accessibilityLabel("Reference, \(reference.name)")
            .accessibilityValue(state.hearingReference ? "hearing" : "not hearing")
        } else {
            Menu {
                referenceChoices
            } label: {
                pillLabel("Compare", hearing: false)
            }
            .menuStyle(.button)
            .buttonBorderShape(.capsule)
            .help("Keep a curve aside to listen against your edit.")
            .accessibilityLabel("Compare: choose a reference")
        }
    }

    private var referenceChoices: some View {
        Group {
            Button("Use Current Curve as Reference") { state.setReference(state.preset, undoManager: undoManager) }
            Divider()
            ForEach(state.store.allPresets) { preset in
                Button(preset.name) { state.setReference(preset, undoManager: undoManager) }
            }
        }
    }

    private func pillLabel(_ name: String, hearing: Bool) -> some View {
        // A macOS Menu label keeps only one Text, so this one is concatenated.
        (Text(Image(systemName: hearing ? "largecircle.fill.circle" : "circle")) + Text("  ") + Text(name))
            .font(.caption)
            .lineLimit(1)
    }

    // MARK: - Toolbar

    /// Height of the window's unified title bar; the inline stand-in used by
    /// the screenshot renderer matches it so renders look like the window.
    static let toolbarHeight: CGFloat = 52
    /// Clears the window controls in the inline stand-in.
    static let toolbarLeadingInset: CGFloat = 84

    /// The same controls the real toolbar carries, laid out as a row for the
    /// offscreen renderer, which cannot draw an NSToolbar or its title menu.
    private var inlineToolbarRow: some View {
        HStack(spacing: 10) {
            inlineTitle
            Spacer()
            saveButton
            revertButton
            bypassToggle
            AppGearMenu()
        }
        .padding(.leading, Self.toolbarLeadingInset)
        .padding(.trailing, 24)
        .frame(height: Self.toolbarHeight)
    }

    @ToolbarContentBuilder
    private var windowToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            saveButton
            revertButton
        }
        ToolbarItemGroup(placement: .primaryAction) {
            bypassToggle
            AppGearMenu()
        }
    }

    /// Stand-in for the window title and its menu in the offscreen render.
    private var inlineTitle: some View {
        Menu {
            presetMenuItems
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(state.preset.name).font(.headline).lineLimit(1)
                if state.presetIsModified {
                    Text("Edited").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.trailing, 16)
    }

    /// The preset list behind the window title: switch, import, delete.
    private var presetMenuItems: some View {
        Group {
            ForEach(state.store.allPresets) { preset in
                Button(preset.name) {
                    state.recordingUndo("Switch Preset", undoManager) { state.apply(preset) }
                }
            }
            Divider()
            Button("Import…") {
                importPresentation = ImportPresentation(profileSuggestion: nil)
            }
            if let stored = state.savedPreset, state.store.customPresets.contains(stored) {
                Divider()
                Button("Delete “\(stored.name)”…", role: .destructive) {
                    WindowManager.shared.confirmDeletePreset(stored)
                }
            }
        }
    }

    private var saveButton: some View {
        Button("Save…") {
            saveName = state.preset.name
            showSaveSheet = true
        }
        .keyboardShortcut("s", modifiers: .command)
        .help("Save the current curve as a preset")
    }

    private var revertButton: some View {
        Button {
            state.recordingUndo("Revert", undoManager) { state.revertPreset() }
        } label: {
            Label("Revert", systemImage: "arrow.counterclockwise")
                .labelStyle(.iconOnly)
        }
        .disabled(!state.presetIsModified)
        .help("Revert to the saved preset")
        .accessibilityLabel("Revert to saved preset")
    }

    private var bypassToggle: some View {
        Toggle("Bypass", isOn: $state.bypassed)
            .toggleStyle(.button)
            .keyboardShortcut("b", modifiers: .command)
            .help("Hear the unprocessed signal without changing the preset (⌘B)")
    }

    // MARK: - Graph

    private var graph: some View {
        VStack(spacing: 3) {
            // The graph shows the EQ shape only — preamp is gain staging,
            // shown in the bottom bar, not baked into the curve.
            EQCurveView(
                bands: state.heardPreset.bands,
                responseBands: state.heardPreset.renderedBands,
                preampDB: 0,
                interactive: !state.hearingReference,
                showSpectrum: state.isEnabled && state.editorIsVisible,
                showIndividualCurves: true,
                rangeDB: state.heardPreset.displayRangeDB,
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
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: state.bypassed)
            .overlay(alignment: .topLeading) {
                Text("+\(Int(state.heardPreset.displayRangeDB)) dB").font(.caption2).foregroundStyle(.secondary).padding(4)
            }
            .overlay(alignment: .bottomLeading) {
                Text("−\(Int(state.heardPreset.displayRangeDB)) dB").font(.caption2).foregroundStyle(.secondary).padding(4)
            }
            .overlay(alignment: .bottomTrailing) {
                if state.isEnabled && !state.bypassed {
                    spectrumLegend
                }
            }
            .overlay(alignment: .topTrailing) {
                // The pill itself shows the hearing state, so no label repeats it.
                HStack(spacing: 10) {
                    if state.bypassed {
                        Label("Bypassed", systemImage: "waveform.slash")
                            .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    } else if bandLimitReached {
                        Text("32 bands maximum")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if state.preset.bands.isEmpty {
                        Label("Double-click graph to add band", systemImage: "plus.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    referencePill.controlSize(.small)
                }
                .padding(4)
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
        .foregroundStyle(.secondary)
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

    /// Cards run low to high in frequency, so the strip reads like the
    /// graph above it. The order freezes for the length of a node drag so a
    /// band crossing another does not shuffle the cards under the pointer.
    private var orderedBands: [EQBand] {
        let reference = (dragStartPreset ?? state.preset).bands.sorted { $0.frequency < $1.frequency }
        let current = Dictionary(state.preset.bands.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var ordered = reference.compactMap { current[$0.id] }
        let known = Set(reference.map(\.id))
        ordered += state.preset.bands.filter { !known.contains($0.id) }
        return ordered
    }

    /// Bands as rows in two or more columns, filled top to bottom then left
    /// to right, so a ten-band preset shows whole with no scrolling. Longer
    /// presets scroll vertically; wider windows add a column.
    private var bandStrip: some View {
        GeometryReader { geo in
            let usable = geo.size.width - 48 + Self.bandColumnSpacing
            let columnCount = max(1, Int(usable / (Self.bandColumnMinWidth + Self.bandColumnSpacing)))
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    bandColumns(count: columnCount)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                }
                // Selecting a handle on the graph brings its row into view, so a
                // 32-band preset never hides the row being edited.
                .onChange(of: selectedBandID) { _, id in
                    guard let id else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
        .frame(height: Self.bandStripHeight)
    }

    static let bandColumnMinWidth: CGFloat = 328
    static let bandColumnSpacing: CGFloat = 12
    /// Six 22 pt rows at 2 pt spacing plus 8 pt above and below: ten bands
    /// and the add row in two columns.
    static let bandStripHeight: CGFloat = 158

    private func bandColumns(count: Int) -> some View {
        let bands = orderedBands
        let itemCount = bands.count + 1
        let rows = Int((Double(itemCount) / Double(count)).rounded(.up))
        return HStack(alignment: .top, spacing: Self.bandColumnSpacing) {
            ForEach(0..<count, id: \.self) { column in
                VStack(spacing: 2) {
                    ForEach(column * rows..<min((column + 1) * rows, itemCount), id: \.self) { position in
                        if position < bands.count {
                            let band = bands[position]
                            BandRow(index: position, band: bandBinding(band.id),
                                    isSelected: selectedBandID == band.id,
                                    onDelete: { deleteBand(band.id) })
                                .onTapGesture { selectedBandID = band.id }
                                .focusable()
                                .focused($focusedBandID, equals: band.id)
                                .id(band.id)
                        } else {
                            addBandRow
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var addBandRow: some View {
        Button {
            addBand(EQBand(type: .peak, frequency: EQBand.openFrequency(among: state.preset.bands), gain: 0, q: 1.41))
        } label: {
            Label("Add Band", systemImage: "plus")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .frame(height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(bandLimitReached)
        .help(bandLimitReached ? "32 bands maximum" : "Add a band in the widest gap between bands")
        .accessibilityLabel("Add band")
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

    private var bandLimitReached: Bool { state.preset.bands.count >= 32 }

    private func addBand(_ band: EQBand) {
        guard !bandLimitReached else { return }
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

    /// Arrow keys move the selected band: up/down change gain by 0.5 dB,
    /// left/right move frequency by a semitone. Option makes both steps fine.
    private func nudgeSelectedBand(_ direction: MoveCommandDirection) {
        guard let id = selectedBandID,
              let i = state.preset.bands.firstIndex(where: { $0.id == id }) else { return }
        let nudge: EQBand.NudgeDirection
        switch direction {
        case .up: nudge = .up
        case .down: nudge = .down
        case .left: nudge = .left
        case .right: nudge = .right
        @unknown default: return
        }
        let fine = NSEvent.modifierFlags.contains(.option)
        let nudged = state.preset.bands[i].nudged(nudge, fine: fine)
        state.recordingUndo("Nudge Band", undoManager) { state.preset.bands[i] = nudged }
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
            Spacer()
            Text("Output")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
            clipIndicator
                .fixedSize(horizontal: true, vertical: false)
        }
        .controlSize(.small)
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    // MARK: - Adjust bar

    /// Tunes the whole profile without editing its bands: two shelves, a
    /// tilt, and how much of the correction to apply. It sits under the band
    /// list so the reason a curve leaves its handles is always on screen.
    private var adjustBar: some View {
        HStack(spacing: 12) {
            Text("Adjust")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
            Grid(horizontalSpacing: 40, verticalSpacing: 8) {
                GridRow {
                    adjustRow("Bass", value: $state.preset.adjustment.bassDB, range: -6...6, step: 0.5,
                              actionName: "Change Bass", format: Self.signedDecibels,
                              help: "Low shelf at 105 Hz")
                    adjustRow("Treble", value: $state.preset.adjustment.trebleDB, range: -6...6, step: 0.5,
                              actionName: "Change Treble", format: Self.signedDecibels,
                              help: "High shelf at 2.5 kHz")
                }
                GridRow {
                    adjustRow("Tilt", value: $state.preset.adjustment.tiltDB, range: -6...6, step: 0.5,
                              actionName: "Change Tilt", format: Self.signedDecibels,
                              help: "Tips the whole response about 1 kHz: up brightens, down warms")
                    adjustRow("Strength", value: strengthPercent, range: 0...150, step: 5,
                              actionName: "Change Strength", format: Self.strengthPercentage, warnAbove: 100,
                              help: "How much of the preset's correction is applied. Above 100 % over-corrects.")
                }
            }
            Spacer(minLength: 0)
            Button("Reset") {
                state.recordingUndo("Reset Adjustments", undoManager) { state.preset.adjustment = .neutral }
            }
            .disabled(state.preset.adjustment.isNeutral)
            .help("Back to the preset as published")
        }
        .controlSize(.small)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private var strengthPercent: Binding<Double> {
        Binding(get: { state.preset.adjustment.strength * 100 },
                set: { state.preset.adjustment.strength = $0 / 100 })
    }

    private static func signedDecibels(_ value: Double) -> String {
        value == 0 ? "0.0 dB" : typographic(String(format: "%+.1f dB", value))
    }

    /// Reads "Off" at zero, like the boost fader, since none of the bands
    /// are heard.
    private static func strengthPercentage(_ value: Double) -> String {
        value == 0 ? "Off" : String(format: "%.0f%%", value)
    }

    /// A drag is one undo step, registered when the knob is released; a
    /// keyboard step registers on its own. The slider's own keyboard
    /// increment is finer than a step, so a key press moves one step in its
    /// direction rather than rounding back to where it was.
    private func adjustRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double,
                           actionName: String, format: @escaping (Double) -> String, warnAbove: Double? = nil,
                           help: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Slider(
                value: Binding(
                    get: { value.wrappedValue },
                    set: { updated in
                        let current = value.wrappedValue
                        var stepped = (updated / step).rounded() * step
                        if adjustDragStart == nil, stepped == current, updated != current {
                            stepped = current + (updated > current ? step : -step)
                        }
                        stepped = min(max(stepped, range.lowerBound), range.upperBound)
                        if adjustDragStart == nil {
                            state.recordingUndo(actionName, undoManager) { value.wrappedValue = stepped }
                        } else {
                            value.wrappedValue = stepped
                        }
                    }
                ),
                in: range,
                onEditingChanged: { editing in
                    if editing {
                        adjustDragStart = state.preset
                    } else if let before = adjustDragStart {
                        adjustDragStart = nil
                        if before != state.preset {
                            state.registerUndo(restoring: before, actionName: actionName, undoManager: undoManager)
                        }
                        state.flushWorkingPresetPersistence()
                    }
                }
            )
            .frame(maxWidth: 220)
            .accessibilityLabel(label)
            .accessibilityValue(format(value.wrappedValue))
            Text(format(value.wrappedValue))
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(warnAbove.map { value.wrappedValue > $0 } == true ? Color.orange : Color.primary)
                .frame(width: 64, alignment: .trailing)
        }
        .help(help)
    }

    /// Output level after the limiter: the current peak, and the highest
    /// since the editor opened so a brief clip is not missed.
    private var clipIndicator: some View {
        PeakMeterView(processor: state.engine.processor, isActive: state.editorIsVisible)
            .frame(width: PeakMeterNSView.preferredWidth, height: 14)
            .help("Output peak after the limiter, and the highest since the editor opened. Click to reset.")
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
            Text(typographic(String(format: "%.1f dB", trackedValue ?? effectiveValue)))
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(isDisabled ? .secondary : .primary)
                .frame(minWidth: 52, alignment: .trailing)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
                .help(isDisabled ? "Chosen automatically. Turn off Auto to set it yourself." : "Preamp")
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

/// Readouts use the true minus sign, like the axis labels, not a hyphen.
fileprivate func typographic(_ readout: String) -> String {
    readout.replacingOccurrences(of: "-", with: "−")
}

/// The peak readout's memory: the latest peak and the highest since reset.
struct PeakHold: Equatable {
    private(set) var currentDB: Double = -60
    private(set) var heldDB: Double = -60

    mutating func push(_ db: Double) {
        currentDB = max(db, -60)
        heldDB = max(heldDB, currentDB)
    }

    mutating func reset() {
        currentDB = -60
        heldDB = -60
    }
}

/// Keeps the display-linked peak readout out of SwiftUI's view graph. Updating this
/// AppKit view redraws only its own small bounds instead of the editor.
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
    /// The current peak, the "dBFS  max" caption, and the held peak. Each
    /// number sits right-aligned in a slot wide enough for "−60.0", so the
    /// readout stays put as digits come and go.
    private let currentLayer = CATextLayer()
    private let captionLayer = CATextLayer()
    private let heldLayer = CATextLayer()
    private let font: NSFont
    private var animationLink: CADisplayLink?
    private var active = false
    private var hold = PeakHold()
    private var renderedLabel = ""
    private var renderedColor: NSColor?

    private static let caption = "dBFS  max"

    /// Width of the widest readout the meter shows.
    static var slotWidth: CGFloat { width(of: typographic("-60.0"), in: meterFont) }
    static var captionWidth: CGFloat { width(of: caption, in: meterFont) }
    /// The full meter width: dot, two number slots, and the caption between.
    static var preferredWidth: CGFloat { 11 + slotWidth + 4 + captionWidth + 4 + slotWidth }

    private static var meterFont: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: NSFont.preferredFont(forTextStyle: .caption1).pointSize,
                                         weight: .regular)
    }

    private static func width(of text: String, in font: NSFont) -> CGFloat {
        ceil(NSAttributedString(string: text, attributes: [.font: font]).size().width)
    }

    init(processor: EQProcessor) {
        self.processor = processor
        self.font = Self.meterFont
        super.init(frame: .zero)
        wantsLayer = true
        dotLayer.actions = ["path": NSNull(), "fillColor": NSNull()]
        for (layer, alignment) in [(currentLayer, CATextLayerAlignmentMode.right),
                                   (captionLayer, .left), (heldLayer, .right)] {
            layer.actions = ["string": NSNull(), "foregroundColor": NSNull(),
                             "bounds": NSNull(), "position": NSNull()]
            layer.font = font
            layer.fontSize = font.pointSize
            layer.alignmentMode = alignment
            self.layer?.addSublayer(layer)
        }
        captionLayer.string = Self.caption
        layer?.addSublayer(dotLayer)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("Output peak")
        updateLayers(force: true)
    }

    /// A click clears the held peak, so the next listen starts clean.
    override func mouseDown(with event: NSEvent) {
        hold.reset()
        updateLayers()
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
        let slot = Self.slotWidth
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        currentLayer.frame = CGRect(x: 11, y: 0, width: slot, height: bounds.height)
        captionLayer.frame = CGRect(x: 11 + slot + 4, y: 0, width: Self.captionWidth, height: bounds.height)
        heldLayer.frame = CGRect(x: 11 + slot + 4 + Self.captionWidth + 4, y: 0, width: slot, height: bounds.height)
        for layer in [currentLayer, captionLayer, heldLayer] { layer.contentsScale = scale }
        CATransaction.commit()
    }

    func setActive(_ active: Bool) {
        guard self.active != active else { return }
        self.active = active
        if active, window != nil {
            startAnimating()
        } else {
            stopAnimating()
            hold.reset()
            updateLayers(force: true)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if active, window != nil { startAnimating() } else { stopAnimating() }
    }

    /// The dot follows the held peak, so a clip that passed in a moment
    /// stays visible until the meter is reset.
    private func updateLayers(force: Bool = false) {
        let held = hold.heldDB
        let color: NSColor = held > -0.1 ? .systemRed : (held > -3 ? .systemOrange : .systemGreen)
        let current = typographic(String(format: "%.1f", hold.currentDB))
        let maximum = typographic(String(format: "%.1f", held))
        let label = "\(current) \(Self.caption) \(maximum)"
        guard force || label != renderedLabel || color != renderedColor else { return }
        renderedLabel = label
        renderedColor = color
        setAccessibilityValue(label)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dotLayer.fillColor = color.cgColor
        currentLayer.string = current
        heldLayer.string = maximum
        // A dynamic colour must be resolved in this view's appearance, or the
        // layer gets the light-mode grey and disappears on a dark window.
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let grey = NSColor.secondaryLabelColor.cgColor
            for layer in [currentLayer, captionLayer, heldLayer] { layer.foregroundColor = grey }
        }
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateLayers(force: true)
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
        hold.push(peak > 0 ? 20 * log10(Double(peak)) : -60)
        updateLayers()
    }

    deinit {
        animationLink?.invalidate()
    }
}

/// One band as a list row: colour dot, number, type menu, then frequency,
/// gain, and Q as click-to-edit fields, and the delete glyph.
struct BandRow: View {
    var index: Int
    @Binding var band: EQBand
    var isSelected: Bool
    var onDelete: () -> Void

    private var color: Color { BandPalette.color(band.colorIndex ?? index) }

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(index + 1)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .frame(width: 16, alignment: .trailing)
            Menu {
                ForEach(FilterType.allCases) { type in
                    Button(type.displayName) { band.type = type }
                }
            } label: {
                Text(band.type.displayName).font(.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .frame(width: 72, alignment: .leading)
            Spacer(minLength: 4)
            valueField("Frequency", value: $band.frequency, range: 20...20000, width: 60,
                       format: freqFormat, parse: parseFreq)
            valueField("Gain", value: $band.gain, range: -30...30, width: 58,
                       format: { typographic(String(format: "%.1f dB", $0)) },
                       parse: { Double($0.replacingOccurrences(of: "dB", with: "").replacingOccurrences(of: "−", with: "-")
                                    .trimmingCharacters(in: .whitespaces)) })
            valueField("Q", value: $band.q, range: 0.1...30, width: 50,
                       format: { String(format: "Q %.2f", $0) },
                       parse: { Double($0.lowercased().replacingOccurrences(of: "q", with: "").trimmingCharacters(in: .whitespaces)) })
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
        .padding(.horizontal, 4)
        .frame(height: 22)
        .background(RoundedRectangle(cornerRadius: 5).fill(isSelected ? color.opacity(0.18) : .clear))
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
    private func valueField(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, width: CGFloat,
                            format: @escaping (Double) -> String,
                            parse: @escaping (String) -> Double?) -> some View {
        // The draft carries the exact unitless value so a band shown as
        // "1.5 kHz" edits as "1534", not "1.5" (which would parse as 1.5 Hz).
        EditableValueField(label: label, text: format(value.wrappedValue),
                           editText: String(format: "%g", value.wrappedValue)) { input in
            if let parsed = parse(input), parsed.isFinite {
                value.wrappedValue = min(max(parsed, range.lowerBound), range.upperBound)
            }
        }
        .frame(width: width)
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
            .accessibilityLabel(label)
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
