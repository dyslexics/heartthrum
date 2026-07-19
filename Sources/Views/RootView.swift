import SwiftUI

struct RootView: View {
    @AppStorage("onboarded") private var onboarded = false
    @State private var selection = 0

    init() {
        // Screenshot/demo support: "-tab N" jumps to a tab (and skips
        // onboarding), "-onboarding" forces the welcome sheet.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let t = Int(args[i + 1]) {
            _selection = State(initialValue: t)
            UserDefaults.standard.set(true, forKey: "onboarded")
        } else if args.contains("-onboarding") {
            UserDefaults.standard.set(false, forKey: "onboarded")
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            MeasureView(selection: $selection)
                .tabItem { Label("Measure", systemImage: "heart.fill") }
                .tag(0)
            HistoryView()
                .tabItem { Label("History", systemImage: "chart.xyaxis.line") }
                .tag(1)
            BreatheView()
                .tabItem { Label("Breathe", systemImage: "wind") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)
        }
        .tint(.pink)
        .fullScreenCover(isPresented: Binding(get: { !onboarded }, set: { onboarded = !$0 })) {
            OnboardingView { onboarded = true }
        }
    }
}

struct OnboardingView: View {
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "heart.fill")
                .font(.system(size: 72))
                .foregroundStyle(.pink)
            Text("Welcome to Heart thrum")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 16) {
                Label("Measure your pulse with your fingertip — right on your iPhone's camera.", systemImage: "camera.fill")
                Label("Free. No ads. No tracking. Your data stays on your device.", systemImage: "lock.shield.fill")
                Label("Follow your well-being over time and relax with guided breathing.", systemImage: "wind")
            }
            .padding(.horizontal)
            Text("Heartthrum is not a medical device. Measurements are for wellness and general well-being purposes only and do not replace professional medical advice.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            Button(action: onDone) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
    }
}

#Preview {
    RootView()
}
