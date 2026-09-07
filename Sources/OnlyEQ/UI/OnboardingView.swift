import SwiftUI

/// First-launch onboarding in the grammar of a macOS setup assistant: one
/// panel of content, a footer with Back and Continue, three steps.
/// Welcome → System Audio access → pick headphones.
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var step = 0
    @State private var searchText = ""
    @State private var isApplying = false
    @State private var applyError: String?
    @State private var selectedEntryID: OnlineEntry.ID?

    static let width: CGFloat = 560
    static let height: CGFloat = 460

    /// The HD 650 correction that ships as a test fixture. Shown on the
    /// welcome panel so the first thing a new user sees is what the app does.
    private static let sampleBands: [EQBand] = {
        guard let url = Bundle.module.url(forResource: "Fixtures/autoeq_parametric.txt", withExtension: nil),
              let preset = try? PresetImporter.importFile(at: url).preset else { return [] }
        return preset.bands
    }()

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: welcome
                case 1: permission
                default: pickHeadphones
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        // Fixed width; the height follows the system text size.
        .frame(width: Self.width)
        .frame(minHeight: Self.height)
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 10) {
                AppBadge(size: 30)
                Text("Welcome to OnlyEQ")
                    .font(.title.weight(.bold))
            }
            Text("A parametric EQ for everything your Mac plays. Nothing to install, nothing to babysit.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .padding(.top, 8)
            // Not a decoration: this is a real headphone correction, the kind
            // the last step imports for your own headphones.
            VStack(spacing: 4) {
                EQCurveView(bands: Self.sampleBands, preampDB: 0, showSpectrum: false, rangeDB: 12)
                    .frame(height: 150)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.035)))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                FrequencyAxisLabels()
            }
            .padding(.top, 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Example correction curve for Sennheiser HD 650 headphones")
            Text("The correction curve for a pair of Sennheiser HD 650s, from AutoEq.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.top, 28)
    }

    private var permission: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("Allow System Audio access")
                .font(.title2.weight(.bold))
            Text("OnlyEQ is asking macOS for the system audio. macOS shows a recording indicator while the EQ runs; audio never leaves your Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button("Open System Settings") { PermissionHelper.openSystemSettings() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            HStack(spacing: 8) {
                if state.engineState == .running && !state.suspectedPermissionIssue {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Access granted").font(.callout.weight(.medium))
                } else {
                    ProgressView().controlSize(.small)
                    Text("Waiting. Play some audio to confirm.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 12)
            .accessibilityElement(children: .combine)
            Spacer()
        }
        .padding(24)
        .onAppear {
            // Starting the engine triggers the system permission prompt.
            if !state.isEnabled { state.isEnabled = true } else { state.rebuildEngine() }
        }
    }

    private var pickHeadphones: some View {
        VStack(spacing: 10) {
            Text("Which headphones do you use?")
                .font(.title2.weight(.bold))
                .padding(.top, 28)
            Text("OnlyEQ imports a correction preset tuned for them and applies it whenever they connect.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            SearchField(text: $searchText, prompt: "Sony WH-1000XM5")
                .padding(.horizontal, 24)
                .padding(.top, 6)

            Group {
                if state.onlineDB.isLoading {
                    ProgressView().frame(maxHeight: .infinity)
                } else if let error = state.onlineDB.error {
                    VStack(spacing: 10) {
                        Label(error, systemImage: "wifi.exclamationmark").foregroundStyle(.secondary)
                        Button("Retry") { Task { await state.onlineDB.load(source: .peqdb) } }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    // Selecting a row only highlights it; "Start Listening"
                    // commits, so the primary button has a job of its own.
                    List(matches, selection: $selectedEntryID) { entry in
                        HStack {
                            Image(systemName: "headphones").foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.model).font(.callout.weight(.medium))
                                Text(entry.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { applyEntry(entry) }
                        .tag(entry.id)
                    }
                    .listStyle(.inset)
                    .overlay {
                        if matches.isEmpty, !searchText.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 16)

            if let applyError {
                Label(applyError, systemImage: "wifi.exclamationmark")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
        .task { await state.onlineDB.load(source: .peqdb) }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") { step -= 1 }
            }
            Spacer()
            switch step {
            case 0:
                Button("Continue") { step = 1 }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            case 1:
                Button("Continue") { step = 2 }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            default:
                Button("Skip and Start Flat") { finish(apply: nil) }
                Button("Start Listening") {
                    if let entry = selectedEntry { applyEntry(entry) }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isApplying || selectedEntry == nil)
            }
        }
        .controlSize(.large)
        .padding(16)
    }

    private var selectedEntry: OnlineEntry? {
        matches.first { $0.id == selectedEntryID }
    }

    private var matches: [OnlineEntry] {
        guard !searchText.isEmpty else { return Array(state.onlineDB.entries.prefix(50)) }
        let terms = searchText.lowercased().split(separator: " ")
        return state.onlineDB.entries.filter { entry in
            let haystack = "\(entry.model) \(entry.reviewer)".lowercased()
            return terms.allSatisfy { haystack.contains($0) }
        }
    }

    private func applyEntry(_ entry: OnlineEntry) {
        isApplying = true
        applyError = nil
        Task {
            defer { isApplying = false }
            do {
                let preset = try await OnlineDatabase.fetchPreset(for: entry)
                finish(apply: state.store.save(preset))
            } catch {
                applyError = "Couldn’t load that preset (\(error.localizedDescription)). Check your connection and press Start Listening again."
            }
        }
    }

    private func finish(apply preset: EQPreset?) {
        if let preset { state.apply(preset) }
        UserDefaults.standard.set(true, forKey: "onboarded")
        WindowManager.shared.closeOnboarding()
    }
}
