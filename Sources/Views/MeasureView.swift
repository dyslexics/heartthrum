import SwiftUI
import SwiftData

struct MeasureView: View {
    @State private var vm = MeasureViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("healthExport") private var healthExport = false

    @State private var selectedTag: MeasureTag?
    @State private var selectedMood: Int?
    @State private var heartBeat = false

    var body: some View {
        NavigationStack {
            VStack {
                switch vm.phase {
                case .idle:
                    idleView
                case .denied:
                    deniedView
                case .noFinger, .measuring:
                    measuringView
                case .done:
                    resultView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Heart thrum")
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active && (vm.phase == .measuring || vm.phase == .noFinger) {
                    vm.cancel()
                }
            }
        }
    }

    private var idleView: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "heart.fill")
                .font(.system(size: 90))
                .foregroundStyle(.pink)
                .scaleEffect(heartBeat ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: heartBeat)
                .onAppear { heartBeat = true }
            Text("Cover the back camera and flash with your fingertip.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                vm.start()
            } label: {
                Text("Start Measurement")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private var deniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Camera access is required to measure your pulse. Please allow it in Settings.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var measuringView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.pink.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: vm.progress)
                    .stroke(Color.pink, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: vm.progress)
                VStack(spacing: 4) {
                    if let bpm = vm.liveBPM, vm.phase == .measuring {
                        Text("\(bpm)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("BPM")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.pink)
                        Text(vm.phase == .measuring ? "Hold still …" : "Place your finger on the camera")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
            }
            .frame(width: 240, height: 240)
            .padding(.top, 20)

            WaveformView(samples: vm.waveform)
                .frame(height: 70)
                .padding(.horizontal)

            if vm.phase == .measuring {
                Label(vm.quality > 0.6 ? "Good signal" : "Keep your finger still on the camera",
                      systemImage: vm.quality > 0.6 ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(vm.quality > 0.6 ? .green : .orange)
            }

            Spacer()
            Button("Stop") { vm.cancel() }
                .buttonStyle(.bordered)
                .padding(.bottom, 24)
        }
    }

    private var resultView: some View {
        VStack(spacing: 20) {
            Text("Measurement complete")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(vm.resultBPM ?? 0)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                Text("BPM")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.pink)

            VStack(alignment: .leading, spacing: 12) {
                Text("Context")
                    .font(.subheadline.bold())
                HStack {
                    ForEach(MeasureTag.allCases) { tag in
                        Button {
                            selectedTag = selectedTag == tag ? nil : tag
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tag.symbol)
                                Text(LocalizedStringKey(tag.labelKey))
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedTag == tag ? Color.pink.opacity(0.2) : Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("How are you feeling?")
                    .font(.subheadline.bold())
                HStack(spacing: 16) {
                    ForEach(1...3, id: \.self) { mood in
                        Button {
                            selectedMood = selectedMood == mood ? nil : mood
                        } label: {
                            Text(["😕", "🙂", "😄"][mood - 1])
                                .font(.system(size: 34))
                                .padding(6)
                                .background(selectedMood == mood ? Color.pink.opacity(0.2) : Color.clear)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    save()
                } label: {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                Button("Discard") { resetAfterResult() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private func save() {
        guard let bpm = vm.resultBPM else { return }
        let record = PulseRecord(bpm: bpm, tag: selectedTag?.rawValue, mood: selectedMood)
        modelContext.insert(record)
        if healthExport {
            HealthManager.shared.saveHeartRate(bpm: bpm, date: record.date)
        }
        resetAfterResult()
    }

    private func resetAfterResult() {
        selectedTag = nil
        selectedMood = nil
        vm.cancel()
    }
}

struct WaveformView: View {
    var samples: [Double]

    var body: some View {
        Canvas { context, size in
            guard samples.count > 1 else { return }
            var path = Path()
            let stepX = size.width / CGFloat(samples.count - 1)
            for (i, v) in samples.enumerated() {
                let x = CGFloat(i) * stepX
                let y = size.height / 2 - CGFloat(v) * size.height * 0.45
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(.pink), lineWidth: 2)
        }
    }
}
