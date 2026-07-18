import SwiftUI

struct RootView: View {
    @AppStorage("onboarded") private var onboarded = false

    var body: some View {
        TabView {
            MeasureView()
                .tabItem { Label("Measure", systemImage: "heart.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "chart.xyaxis.line") }
            BreatheView()
                .tabItem { Label("Breathe", systemImage: "wind") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(.pink)
        .sheet(isPresented: Binding(get: { !onboarded }, set: { onboarded = !$0 })) {
            OnboardingView { onboarded = true }
                .interactiveDismissDisabled()
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
            Text("Welcome to Heartthrum")
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
