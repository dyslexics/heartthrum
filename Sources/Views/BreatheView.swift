import SwiftUI

struct BreatheView: View {
    enum Duration: Int, CaseIterable, Identifiable {
        case one = 60, three = 180, five = 300
        var id: Int { rawValue }
        var labelKey: String {
            switch self {
            case .one: return "1 minute"
            case .three: return "3 minutes"
            case .five: return "5 minutes"
            }
        }
    }

    private static let inhale: Double = 4
    private static let exhale: Double = 6

    @State private var duration: Duration = .three
    @State private var running = false
    @State private var finished = false
    @State private var scale: CGFloat = 1.0
    @State private var phaseIsInhale = true
    @State private var remaining = 0
    @State private var task: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.15))
                        .frame(width: 260, height: 260)
                    Circle()
                        .fill(Color.teal.opacity(0.35))
                        .frame(width: 170, height: 170)
                        .scaleEffect(scale)
                    if running {
                        Text(phaseIsInhale ? "Breathe in" : "Breathe out")
                            .font(.title3.bold())
                            .foregroundStyle(.teal)
                    } else if finished {
                        Text("Well done!")
                            .font(.title3.bold())
                            .foregroundStyle(.teal)
                    } else {
                        Image(systemName: "wind")
                            .font(.system(size: 44))
                            .foregroundStyle(.teal)
                    }
                }

                if running {
                    Text(timeString(remaining))
                        .font(.system(.title2, design: .monospaced).bold())
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 12) {
                        Text("Guided breathing")
                            .font(.title2.bold())
                        Text("Slow breathing — about six breaths per minute — can help you relax.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Picker("Duration", selection: $duration) {
                            ForEach(Duration.allCases) { d in
                                Text(LocalizedStringKey(d.labelKey)).tag(d)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 32)
                    }
                }

                Spacer()

                Button {
                    running ? stop() : start()
                } label: {
                    Text(running ? "Done" : "Start")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Breathe")
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-demoBreathe") && !running {
                    start()
                }
            }
            .onDisappear { stop() }
        }
    }

    private func start() {
        finished = false
        running = true
        remaining = duration.rawValue
        UIApplication.shared.isIdleTimerDisabled = true
        task = Task {
            let end = Date().addingTimeInterval(Double(duration.rawValue))
            while !Task.isCancelled && Date() < end {
                phaseIsInhale = true
                withAnimation(.easeInOut(duration: Self.inhale)) { scale = 1.45 }
                if (try? await Task.sleep(for: .seconds(Self.inhale))) == nil { break }
                remaining = max(0, Int(end.timeIntervalSinceNow))
                guard !Task.isCancelled && Date() < end else { break }
                phaseIsInhale = false
                withAnimation(.easeInOut(duration: Self.exhale)) { scale = 1.0 }
                if (try? await Task.sleep(for: .seconds(Self.exhale))) == nil { break }
                remaining = max(0, Int(end.timeIntervalSinceNow))
            }
            if !Task.isCancelled {
                finished = true
            }
            cleanup()
        }
    }

    private func stop() {
        task?.cancel()
        task = nil
        cleanup()
    }

    private func cleanup() {
        running = false
        UIApplication.shared.isIdleTimerDisabled = false
        withAnimation(.easeInOut(duration: 1)) { scale = 1.0 }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
