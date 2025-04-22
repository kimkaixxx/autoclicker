import SwiftUI
import ApplicationServices
import AppKit

struct ContentView: View {
    @State private var profileNames: [String] = ["Default", "Profile 1", "Profile 2", "Profile 3"]
    @State private var profileIntervals: [String] = ["30", "", "", ""]
    @State private var selectedProfileIndex: Int = 0
    @State private var timer: Timer? = nil
    @State private var isRunning = false
    @State private var log: String = ""
    @State private var clickCount: Int = 0
    @State private var globalMonitor: Any? = nil
    @State private var localMonitor: Any? = nil

    var body: some View {
        VStack(spacing: 12) {
            // Profile picker
            HStack {
                Text("Profile:")
                Picker(selection: $selectedProfileIndex, label: Text("Profile")) {
                    ForEach(0..<profileNames.count, id: \.self) { index in
                        Text(profileNames[index]).tag(index)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }

            // Name editor for selected profile
            HStack {
                Text("Name:")
                TextField("Profile Name", text: Binding(
                    get: { profileNames[selectedProfileIndex] },
                    set: { profileNames[selectedProfileIndex] = $0 }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(isRunning)
            }

            // Interval editor for selected profile
            HStack {
                Text("Interval (s):")
                TextField("Seconds", text: Binding(
                    get: { profileIntervals[selectedProfileIndex] },
                    set: { profileIntervals[selectedProfileIndex] = $0 }
                ))
                .frame(width: 60)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(isRunning)
            }

            // Save & Start/Stop buttons
            HStack(spacing: 20) {
                Button("Save") {
                    saveProfile()
                }
                .disabled(isRunning)

                Button(isRunning ? "Stop" : "Start") {
                    isRunning ? stopClicking() : startClicking()
                }
                .keyboardShortcut(.defaultAction)
            }

            // Status and count
            VStack(alignment: .leading, spacing: 4) {
                Text(log)
                    .font(.caption)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Clicks: \(clickCount)")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .onAppear {
            loadProfiles()
            // Register global and local key monitors for ⌘+Shift+S
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                handleHotkey(event)
            }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handleHotkey(event)
                return event
            }
        }
        .onDisappear {
            // Cleanup monitors
            if let gm = globalMonitor {
                NSEvent.removeMonitor(gm)
            }
            if let lm = localMonitor {
                NSEvent.removeMonitor(lm)
            }
        }
    }

    // Handle ⌘+Shift+S to toggle start/stop
    private func handleHotkey(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) && flags.contains(.shift),
           let chars = event.charactersIgnoringModifiers?.uppercased(), chars == "S" {
            DispatchQueue.main.async {
                if isRunning { stopClicking() } else { startClicking() }
            }
        }
    }

    // Load saved names and intervals from UserDefaults
    private func loadProfiles() {
        for index in 0..<profileNames.count {
            let nameKey = "profile_name_\(index)"
            if let savedName = UserDefaults.standard.string(forKey: nameKey), !savedName.isEmpty {
                profileNames[index] = savedName
            }
            let intervalKey = "profile_interval_\(index)"
            if let savedInterval = UserDefaults.standard.string(forKey: intervalKey), !savedInterval.isEmpty {
                profileIntervals[index] = savedInterval
            }
        }
        log = "Loaded saved profiles"
    }

    // Save current name and interval to UserDefaults
    private func saveProfile() {
        let nameKey = "profile_name_\(selectedProfileIndex)"
        let intervalKey = "profile_interval_\(selectedProfileIndex)"
        let name = profileNames[selectedProfileIndex]
        let interval = profileIntervals[selectedProfileIndex]
        UserDefaults.standard.set(name, forKey: nameKey)
        UserDefaults.standard.set(interval, forKey: intervalKey)
        log = "Saved \(name): \(interval)s"
    }

    func startClicking() {
        let secsText = profileIntervals[selectedProfileIndex]
        guard let secs = Double(secsText), secs > 0 else {
            log = "Invalid interval for \(profileNames[selectedProfileIndex])"
            return
        }
        isRunning = true
        clickCount = 0
        log = "Clicking every \(Int(secs))s (\(profileNames[selectedProfileIndex]))..."
        timer = Timer.scheduledTimer(withTimeInterval: secs, repeats: true) { _ in
            clickMouse()
        }
    }

    func stopClicking() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        log = "Stopped."
    }

    func clickMouse() {
        guard let loc = CGEvent(source: nil)?.location else { return }
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                           mouseCursorPosition: loc, mouseButton: .left)
        let up   = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                           mouseCursorPosition: loc, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        clickCount += 1
        log = "Clicked at \(Int(loc.x)),\(Int(loc.y))"
    }
}
