import SwiftUI

/// First-launch onboarding: welcome → permission → pick headphones.
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var step = 0
    @State private var searchText = ""
    @State private var isApplying = false
    @State private var applyError: String?
    @State private var selectedEntryID: OnlineEntry.ID?

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

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.bottom, 16)
        }
        .frame(width: 520, height: 440)
    }

    private var welcome: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white)
                .frame(width: 88, height: 88)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.accentColor))
            Text("System-wide EQ\nfor your Mac")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text("A parametric EQ for everything your Mac plays. Nothing to install, nothing to babysit.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Get Started") { step = 1 }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Spacer().frame(height: 8)
        }
        .padding(24)
    }

    private var permission: some View {
        VStack(spacing: 12) {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "menubar.rectangle").font(.largeTitle).foregroundStyle(.secondary)
                Image(systemName: "record.circle").font(.title2).foregroundStyle(.purple)
            }
            Text("Allow System Audio access")
                .font(.title.weight(.bold))
            Text("macOS shows a recording indicator while EQ is active.\nAudio never leaves your Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open System Settings") { PermissionHelper.openSystemSettings() }
                .buttonStyle(.borderedProminent)
            Button("I’ve Enabled It") { step = 2 }

            GroupBox {
                HStack(spacing: 8) {
                    if state.engineState == .running && !state.suspectedPermissionIssue {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Permission granted").font(.callout.weight(.medium))
                    } else {
                        ProgressView().controlSize(.small)
                        Text("Waiting… play some audio to confirm")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
                .padding(4)
            }
            .frame(width: 320)
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
            Text("Search your headphones\nto auto-EQ them")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.top, 18)
            Text("Pick your headphones to import a preset tuned for them.")
                .font(.callout).foregroundStyle(.secondary)

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Sony WH-1000XM5", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
            .padding(.horizontal, 20)

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
            .padding(.horizontal, 12)

            if let applyError {
                Label(applyError, systemImage: "wifi.exclamationmark")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }

            HStack {
                Button("Skip and Start Flat") { finish(apply: nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Start Listening") {
                    if let entry = selectedEntry { applyEntry(entry) }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isApplying || selectedEntry == nil)
            }
            .padding(16)
        }
        .task { await state.onlineDB.load(source: .peqdb) }
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
