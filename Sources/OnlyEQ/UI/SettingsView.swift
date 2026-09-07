import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            DeviceSettings()
                .tabItem { Label("Devices", systemImage: "headphones") }
            SoundSettings()
                .tabItem { Label("Sound", systemImage: "waveform") }
            ShortcutSettings()
                .tabItem { Label("Shortcuts", systemImage: "command") }
            AdvancedSettings()
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
    }
}

// MARK: - General

struct GeneralSettings: View {
    @EnvironmentObject var state: AppState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("showLatency") private var showLatency = true

    var body: some View {
        Form {
            Toggle(isOn: $launchAtLogin) {
                Text("Launch at login")
                Text("Start OnlyEQ automatically when you log in.")
            }
            .onChange(of: launchAtLogin) { _, enabled in
                do {
                    if enabled { try SMAppService.mainApp.register() }
                    else { try SMAppService.mainApp.unregister() }
                } catch {
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }

            Toggle(isOn: $showLatency) {
                Text("Show latency in popover")
                Text("Display system audio latency in the popover.")
            }

            Toggle(isOn: $state.autoSuggestHeadphoneProfiles) {
                Text("Suggest profiles for new Bluetooth headphones")
                Text("Open preset search when an unrecognized Bluetooth output becomes active.")
            }

            Section {
                LabeledContent("OnlyEQ") {
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                LabeledContent("macOS") {
                    Text(systemVersion)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "dev"
        guard let build = info?["CFBundleVersion"] as? String else { return version }
        return "\(version) (\(build))"
    }

    private var systemVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
            .replacingOccurrences(of: "Version ", with: "")
    }
}

// MARK: - Devices

struct DeviceSettings: View {
    @EnvironmentObject var state: AppState
    @State private var showAppPicker = false
    @State private var selectedExcluded: String?

    var body: some View {
        Form {
            Section {
                ForEach(state.devices) { device in
                    deviceRow(device)
                }
            } header: {
                Text("Output Devices")
            } footer: {
                Text("OnlyEQ switches presets automatically when a device connects.")
            }

            Section {
                List(selection: $selectedExcluded) {
                    ForEach(Array(state.excludedBundleIDs).sorted(), id: \.self) { bundleID in
                        Label {
                            Text(appName(for: bundleID))
                        } icon: {
                            appIcon(for: bundleID)
                        }
                        .tag(bundleID)
                    }
                }
                .frame(minHeight: 60)
                HStack(spacing: 8) {
                    Button {
                        pickApp()
                    } label: { Image(systemName: "plus") }
                        .help("Add app")
                        .accessibilityLabel("Add app")
                    Button {
                        if let selected = selectedExcluded {
                            state.excludedBundleIDs.remove(selected)
                            selectedExcluded = nil
                        }
                    } label: { Image(systemName: "minus") }
                        .help("Remove app")
                        .accessibilityLabel("Remove app")
                        .disabled(selectedExcluded == nil)
                    Spacer()
                }
                .controlSize(.small)
            } header: {
                Text("Excluded Apps")
            } footer: {
                Text("Audio from these apps is never processed. Add DAWs and call apps that manage their own audio.")
            }
        }
        .formStyle(.grouped)
    }

    private func deviceRow(_ device: AudioOutputDevice) -> some View {
        let profile = state.store.deviceProfiles[device.uid]
        return HStack {
            Label(device.name, systemImage: device.icon)
            Spacer()
            Menu {
                Button("None") {
                    state.store.setProfile(deviceUID: device.uid, deviceName: device.name, preset: nil,
                                           autoApply: profile?.autoApply ?? true)
                }
                Divider()
                ForEach(state.store.allPresets) { preset in
                    Button(preset.name) {
                        state.store.setProfile(deviceUID: device.uid, deviceName: device.name, preset: preset,
                                               autoApply: profile?.autoApply ?? true)
                    }
                }
            } label: {
                Text(profile?.presetName ?? "None")
                    .font(.subheadline)
            }
            .frame(maxWidth: 190)
            Toggle("", isOn: Binding(
                get: { profile?.autoApply ?? false },
                set: { enabled in
                    state.store.setProfile(deviceUID: device.uid, deviceName: device.name,
                                           preset: state.store.preset(withID: profile?.presetID), autoApply: enabled)
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let bundleID = Bundle(url: url)?.bundleIdentifier {
                    state.excludedBundleIDs.insert(bundleID)
                }
            }
        }
    }

    private func appName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleID
    }

    private func appIcon(for bundleID: String) -> Image {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
        }
        return Image(systemName: "app.dashed")
    }
}

// MARK: - Shortcuts

struct ShortcutSettings: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section {
                ForEach(HotKeyManager.Action.allCases) { action in
                    HStack {
                        Text(action.title)
                        Spacer()
                        Text(action.chordDescription)
                            .font(.system(.subheadline, design: .monospaced))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 5).fill(.quaternary.opacity(0.6)))
                        Toggle("", isOn: Binding(
                            get: { HotKeyManager.shared.isEnabled(action) },
                            set: { HotKeyManager.shared.setEnabled(action, $0) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }
                }
            } header: {
                Text("Global Shortcuts")
            } footer: {
                Text("Shortcuts work in any app while OnlyEQ is running.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Sound

struct SoundSettings: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $state.limiterEnabled) {
                    Text("Limiter")
                    Text("Prevent clipping by limiting output level.")
                }
                if state.limiterEnabled {
                    LabeledContent("Ceiling") {
                        Slider(value: $state.limiterCeilingDB, in: -6.0...(-0.1)) {
                            Text("Ceiling")
                        }
                        Text(String(format: "%.1f dBFS", state.limiterCeilingDB))
                            .font(.subheadline.monospacedDigit())
                            .frame(width: 64, alignment: .trailing)
                    }
                }
            }

            Section {
                Toggle(isOn: $state.crossfeedEnabled) {
                    Text("Crossfeed")
                    Text("Blend a little of each channel into the other, as speakers do, so hard-panned recordings sound less split on headphones.")
                }
                if state.crossfeedEnabled {
                    Picker("Profile", selection: $state.crossfeedPreset) {
                        ForEach(CrossfeedPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    if state.crossfeedPreset == .custom {
                        LabeledContent("Amount") {
                            Slider(value: $state.crossfeedLevelDB, in: -12.0...(-3.0)) {
                                Text("Amount")
                            }
                            Text(String(format: "%.1f dB", state.crossfeedLevelDB))
                                .font(.subheadline.monospacedDigit())
                                .frame(width: 64, alignment: .trailing)
                        }
                        LabeledContent("Cutoff") {
                            Slider(value: $state.crossfeedCutoffHz, in: 400...1000, step: 10) {
                                Text("Cutoff")
                            }
                            Text(String(format: "%.0f Hz", state.crossfeedCutoffHz))
                                .font(.subheadline.monospacedDigit())
                                .frame(width: 64, alignment: .trailing)
                        }
                    }
                }
            }

            Section {
                Toggle(isOn: $state.loudnessEnabled) {
                    Text("Loudness compensation")
                    Text("Raise bass and treble as the volume drops below your reference level, so quiet listening keeps its balance.")
                }
                if state.loudnessEnabled {
                    LabeledContent {
                        HStack {
                            Text("\(Int(state.loudnessReferencePercent))%")
                                .font(.subheadline.monospacedDigit())
                            Button("Use Current Volume") {
                                state.loudnessReferencePercent = state.volumePercent
                            }
                        }
                    } label: {
                        Text("Reference volume")
                        Text("Your normal listening level. No compensation is applied at or above it.")
                    }
                }
            }

        }
        .formStyle(.grouped)
    }
}

// MARK: - Advanced

struct AdvancedSettings: View {
    @EnvironmentObject var state: AppState
    @State private var confirmReset = false

    var body: some View {
        Form {
            Picker(selection: $state.bufferFrames) {
                Text("128 frames").tag(128)
                Text("256 frames").tag(256)
                Text("512 frames").tag(512)
                Text("1024 frames").tag(1024)
            } label: {
                Text("Buffer Size")
                Text("Larger = more stable, more latency. Current latency ≈ \(state.latencyMilliseconds) ms.")
            }

            Picker(selection: $state.maxBoostPercent) {
                Text("100% (no boost)").tag(100.0)
                Text("150%").tag(150.0)
                Text("200%").tag(200.0)
            } label: {
                Text("Boost Range")
                Text("Maximum volume boost allowed.")
            }

            Section {
                LabeledContent {
                    Button("Reset…", role: .destructive) { confirmReset = true }
                } label: {
                    Text("Reset all settings…")
                    Text("This will reset all preferences to their defaults.")
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Reset all OnlyEQ settings?", isPresented: $confirmReset) {
            Button("Reset Everything", role: .destructive) { resetAll() }
        } message: {
            Text("Presets, device profiles, and preferences will be removed.")
        }
    }

    private func resetAll() {
        state.resetToDefaults()
    }
}
