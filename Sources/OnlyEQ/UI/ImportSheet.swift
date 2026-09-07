import SwiftUI
import UniformTypeIdentifiers

/// Three-tab import sheet: drop file, paste text, browse online (peqdb/AutoEq).
struct ImportSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    let profileSuggestion: ProfileSuggestion?

    enum Tab: String, CaseIterable { case drop = "Drop file", paste = "Paste text", browse = "Browse online" }
    @State private var tab: Tab = .drop
    @State private var isDropTargeted = false

    // Shared staged result.
    @State private var staged: PresetImporter.ImportResult?
    @State private var errorMessage: String?

    // Paste tab.
    @State private var pastedText = ""
    @State private var parseTask: Task<Void, Never>?

    // Browse tab.
    @State private var searchText = ""
    @State private var source: OnlineEntry.Source = .peqdb
    @State private var selectedEntry: OnlineEntry?
    @State private var previewPreset: EQPreset?
    @State private var isFetchingPreview = false
    @State private var previewTask: Task<Void, Never>?
    @State private var attemptedAutomaticSelection = false

    init(profileSuggestion: ProfileSuggestion? = nil) {
        self.profileSuggestion = profileSuggestion
        _tab = State(initialValue: profileSuggestion == nil ? .drop : .browse)
        _searchText = State(initialValue: profileSuggestion?.searchQuery ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(12)

            Divider()

            Group {
                switch tab {
                case .drop: dropTab
                case .paste: pasteTab
                case .browse: browseTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            footer
        }
        .frame(width: 560, height: 470)
        .task(id: source) {
            if tab == .browse {
                await state.onlineDB.load(source: source)
                selectSuggestedResultIfNeeded()
            }
        }
        .onChange(of: tab) { _, newTab in
            if newTab == .browse { Task { await state.onlineDB.load(source: source) } }
        }
    }

    // MARK: - Drop tab

    private var dropTab: some View {
        VStack(spacing: 14) {
            VStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
                Text("Drop any EQ preset")
                    .font(.title3.weight(.semibold))
                Text("Drop a file here to import")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Choose File…") { chooseFile() }
            }
            .frame(maxWidth: .infinity, minHeight: 200)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDropTargeted ? Color.accentColor.opacity(0.08) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1.5, dash: [6]))
                            .foregroundStyle(isDropTargeted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                    )
            )
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }

            VStack(spacing: 6) {
                Text("Supported formats").font(.caption).foregroundStyle(.tertiary)
                FlowPills(items: ["AutoEq", "Equalizer APO", "peqdb", "Wavelet / GraphicEQ",
                                  "Poweramp JSON", "OPRA JSON", "Peace", "REW", "eqMac"])
            }

            stagedPreview
        }
        .padding(16)
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            stage { try PresetImporter.importFile(at: url) }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            DispatchQueue.main.async {
                stage { try PresetImporter.importFile(at: url) }
            }
        }
        return true
    }

    // MARK: - Paste tab

    private var pasteTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Paste EQ data or presets in any supported text format.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button("Clear") {
                    pastedText = ""
                    staged = nil
                    errorMessage = nil
                }
                .controlSize(.small)
                .disabled(pastedText.isEmpty)
            }
            TextEditor(text: $pastedText)
                .font(.system(.subheadline, design: .monospaced))
                .frame(minHeight: 150)
                .overlay(alignment: .topLeading) {
                    if pastedText.isEmpty {
                        Text("Preamp: -6.1 dB\nFilter 1: ON PK Fc 105 Hz Gain 6.4 dB Q 0.70")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 1).padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                // onChange rather than .task(id:) so switching to this tab
                // does not re-run the handler and clear a preset staged from
                // the Drop or Browse tab.
                .onChange(of: pastedText) { _, newText in
                    parseTask?.cancel()
                    let text = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else {
                        staged = nil
                        errorMessage = nil
                        return
                    }
                    // Let multi-line paste and ordinary typing settle before parsing,
                    // so a half-typed line does not flash an error.
                    parseTask = Task {
                        guard (try? await Task.sleep(for: .milliseconds(600))) != nil else { return }
                        stage { try PresetImporter.importText(text) }
                    }
                }
            stagedPreview
        }
        .padding(16)
    }

    // MARK: - Browse tab

    private var browseTab: some View {
        VStack(spacing: 8) {
            if let profileSuggestion {
                HStack(spacing: 7) {
                    Image(systemName: "headphones.circle.fill").foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("New headphones detected")
                            .font(.subheadline.weight(.semibold))
                        Text(profileSuggestion.deviceName)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text("Review before applying")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.accentColor.opacity(0.09)))
            }

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search \(source == .peqdb ? "peqdb" : "AutoEq") headphones…", text: $searchText)
                    .textFieldStyle(.plain)
                Picker("Source", selection: $source) {
                    ForEach(OnlineEntry.Source.allCases) { Text($0.rawValue).tag($0) }
                }
                .fixedSize()
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))

            if state.onlineDB.isLoading {
                Spacer()
                ProgressView("Loading database…")
                Spacer()
            } else if let error = state.onlineDB.error {
                Spacer()
                VStack(spacing: 10) {
                    Label(error, systemImage: "wifi.exclamationmark").foregroundStyle(.secondary)
                    Button("Retry") { Task { await state.onlineDB.load(source: source) } }
                }
                Spacer()
            } else {
                HSplitView {
                    resultsList
                    previewPane
                }
            }
        }
        .padding(12)
    }

    private var filteredEntries: [OnlineEntry] {
        let all = state.onlineDB.entries
        guard !searchText.isEmpty else { return Array(all.prefix(200)) }
        let terms = searchText.lowercased().split(separator: " ")
        return all.filter { entry in
            let haystack = "\(entry.model) \(entry.reviewer)".lowercased()
            return terms.allSatisfy { haystack.contains($0) }
        }
    }

    private func selectSuggestedResultIfNeeded() {
        guard profileSuggestion != nil, !attemptedAutomaticSelection else { return }
        guard let best = filteredEntries.max(by: {
            HeadphoneNameMatcher.score(query: searchText, candidate: $0.model)
                < HeadphoneNameMatcher.score(query: searchText, candidate: $1.model)
        }) else {
            if source == .peqdb {
                source = .autoEq
            } else {
                attemptedAutomaticSelection = true
            }
            return
        }
        attemptedAutomaticSelection = true
        selectedEntry = best
        fetchPreview()
    }

    private var resultsList: some View {
        List(filteredEntries, selection: Binding(
            get: { selectedEntry?.id },
            set: { id in
                selectedEntry = filteredEntries.first { $0.id == id }
                fetchPreview()
            }
        )) { entry in
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.model).font(.callout.weight(.medium)).lineLimit(1)
                Text(entry.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .tag(entry.id)
        }
        .listStyle(.inset)
        .frame(minWidth: 220)
        .overlay {
            if filteredEntries.isEmpty, !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private var previewPane: some View {
        VStack(spacing: 8) {
            if isFetchingPreview {
                Spacer()
                ProgressView()
                Spacer()
            } else if let preview = previewPreset {
                Text(preview.name).font(.callout.weight(.semibold)).lineLimit(1)
                EQCurveView(bands: preview.bands, preampDB: 0, showSpectrum: false, rangeDB: preview.displayRangeDB)
                    .frame(height: 110)
                Grid(alignment: .leading, verticalSpacing: 3) {
                    GridRow {
                        Text("Preamp").foregroundStyle(.secondary)
                        Text(String(format: "%.1f dB", preview.preampDB))
                    }
                    GridRow {
                        Text("Filters").foregroundStyle(.secondary)
                        Text("\(preview.bands.count)")
                    }
                    GridRow {
                        Text("Source").foregroundStyle(.secondary)
                        Text(preview.source ?? "—")
                    }
                }
                .font(.caption)
                Spacer()
            } else if let errorMessage {
                Spacer()
                Label(errorMessage, systemImage: "xmark.octagon")
                    .font(.subheadline).foregroundStyle(.red)
                Button("Retry") { fetchPreview() }.controlSize(.small)
                Spacer()
            } else {
                Spacer()
                Text("Select a headphone to preview its EQ")
                    .font(.subheadline).foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(10)
        .frame(minWidth: 180, maxWidth: .infinity)
    }

    private func fetchPreview() {
        guard let entry = selectedEntry else { return }
        previewTask?.cancel()
        isFetchingPreview = true
        previewPreset = nil
        staged = nil
        errorMessage = nil
        previewTask = Task {
            // A newer selection cancels this task; only the latest publishes.
            do {
                let preset = try await OnlineDatabase.fetchPreset(for: entry)
                guard !Task.isCancelled else { return }
                isFetchingPreview = false
                previewPreset = preset
                staged = PresetImporter.ImportResult(preset: preset, detectedFormat: entry.source.rawValue)
            } catch {
                guard !Task.isCancelled else { return }
                isFetchingPreview = false
                errorMessage = "Couldn’t fetch preset: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Shared preview + footer

    @ViewBuilder
    private var stagedPreview: some View {
        if let staged {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Live preview").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(staged.preset.bands.count) filters recognized · \(staged.detectedFormat)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                EQCurveView(bands: staged.preset.bands, preampDB: 0, showSpectrum: false, rangeDB: staged.preset.displayRangeDB)
                    .frame(height: 80)
                ForEach(staged.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        } else if let errorMessage {
            Label(errorMessage, systemImage: "xmark.octagon")
                .font(.subheadline).foregroundStyle(.red)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(profileSuggestion == nil ? "Apply" : "Use for This Device") {
                if let staged {
                    if let profileSuggestion {
                        state.assignSuggestedPreset(staged.preset, to: profileSuggestion)
                    } else {
                        // Save before applying so the preset stays in the
                        // picker after switching to another one.
                        state.apply(state.store.save(uniquelyNamed(staged.preset)))
                    }
                    dismiss()
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(staged == nil)
        }
        .padding(12)
    }

    /// Pasted text yields the generic name "Imported"; number it so a second
    /// paste does not replace the first saved preset.
    private func uniquelyNamed(_ preset: EQPreset) -> EQPreset {
        let taken = Set(state.store.allPresets.map(\.name))
        guard taken.contains(preset.name), preset.name == "Imported" else { return preset }
        var named = preset
        var n = 2
        while taken.contains("Imported \(n)") { n += 1 }
        named.name = "Imported \(n)"
        return named
    }

    private func stage(_ work: () throws -> PresetImporter.ImportResult) {
        do {
            staged = try work()
            errorMessage = nil
        } catch {
            staged = nil
            errorMessage = error.localizedDescription
        }
    }
}

/// Wrapping row of small gray capsule labels, wrapped by available width.
struct FlowPills: View {
    var items: [String]

    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(.quaternary.opacity(0.6)))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Lays subviews out left to right, starting a new centred row when the next
/// one would not fit the proposed width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if !row.indices.isEmpty, needed > width {
                rows.append(row)
                row = Row()
            }
            row.indices.append(index)
            row.width = row.indices.count == 1 ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
