import SwiftUI

struct SettingsView: View {
    @AppStorage("healthExport") private var healthExport = false
    @State private var showHealthDenied = false

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Apple Health") {
                    Toggle("Save measurements to Apple Health", isOn: $healthExport)
                        .onChange(of: healthExport) { _, on in
                            guard on else { return }
                            HealthManager.shared.requestAuthorization { granted in
                                if !granted {
                                    healthExport = false
                                    showHealthDenied = true
                                }
                            }
                        }
                }
                Section("About") {
                    Text("Heartthrum is not a medical device. Measurements are for wellness and general well-being purposes only and do not replace professional medical advice.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Free. No ads. No tracking. Your data stays on your device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("Privacy Policy", destination: URL(string: "https://heartthrum.com/privacy.html")!)
                    LabeledContent("Version", value: version)
                }
            }
            .navigationTitle("Settings")
            .alert("Apple Health access was not granted. You can change this in the Health app.", isPresented: $showHealthDenied) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}
