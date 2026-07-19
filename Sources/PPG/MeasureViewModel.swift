import Foundation
import Observation

@Observable
final class MeasureViewModel {

    enum Phase: Equatable {
        case idle
        case denied          // camera permission missing
        case noFinger        // running, waiting for finger
        case measuring       // collecting
        case done            // result ready
    }

    static let measureDuration: Double = 40
    /// "-demoMeasure": synthetic pulse signal through the real pipeline —
    /// for simulator demo videos (no camera available there)
    static let isDemo = ProcessInfo.processInfo.arguments.contains("-demoMeasure")
    private var duration: Double { Self.isDemo ? 12 : Self.measureDuration }

    var phase: Phase = .idle
    var liveBPM: Int?
    var quality: Double = 0
    var progress: Double = 0
    var waveform: [Double] = []
    var resultBPM: Int?

    private let camera = CameraManager()
    private let processor = PulseProcessor()

    private var measureStart: Double?
    private var lastFingerSeen: Double?
    private var exposureLocked = false
    private var demoTask: Task<Void, Never>?
    /// (time, bpm) readings collected during the measurement window
    private var readings: [(Double, Double)] = []

    init() {
        camera.onSample = { [weak self] sample in
            self?.handle(sample)
        }
    }

    func start() {
        if Self.isDemo {
            processor.reset()
            readings = []
            measureStart = nil
            progress = 0
            resultBPM = nil
            phase = .noFinger
            runDemoSignal()
            return
        }
        CameraManager.requestAccess { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.phase = .denied
                return
            }
            self.processor.reset()
            self.readings = []
            self.measureStart = nil
            self.exposureLocked = false
            self.progress = 0
            self.resultBPM = nil
            self.phase = .noFinger
            self.camera.start()
        }
    }

    private func runDemoSignal() {
        demoTask?.cancel()
        demoTask = Task { [weak self] in
            var t = 0.0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 33_000_000)
                t += 1.0 / 30.0
                let finger = t > 2.5
                let pulse = sin(2 * .pi * 1.17 * t) + 0.3 * sin(4 * .pi * 1.17 * t)
                let r = finger ? 0.82 + 0.022 * pulse + Double.random(in: -0.003...0.003) : 0.12
                self?.handle(CameraManager.FrameSample(time: t, red: r,
                                                       green: finger ? 0.24 : 0.10,
                                                       blue: finger ? 0.11 : 0.09))
            }
        }
    }

    func cancel() {
        demoTask?.cancel()
        camera.stop()
        phase = .idle
        progress = 0
        liveBPM = nil
        waveform = []
    }

    private func handle(_ sample: CameraManager.FrameSample) {
        let out = processor.process(sample)
        let now = sample.time

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.phase == .noFinger || self.phase == .measuring else { return }

            self.waveform = out.waveform
            self.quality = out.quality
            self.liveBPM = out.bpm.map { Int($0.rounded()) }

            if out.fingerDetected {
                self.lastFingerSeen = now
                if self.phase == .noFinger {
                    self.phase = .measuring
                    self.measureStart = now
                    self.readings = []
                }
                if !self.exposureLocked, let start = self.measureStart, now - start > 1.5 {
                    self.exposureLocked = true
                    self.camera.lockExposure()
                }
                if let bpm = out.bpm, out.quality > 0.3 {
                    self.readings.append((now, bpm))
                }
                if let start = self.measureStart {
                    self.progress = min(1, (now - start) / self.duration)
                    if now - start >= self.duration {
                        self.finish()
                    }
                }
            } else if self.phase == .measuring {
                // Finger lifted: tolerate 1.5 s, then restart
                if let seen = self.lastFingerSeen, now - seen > 1.5 {
                    self.phase = .noFinger
                    self.measureStart = nil
                    self.progress = 0
                    self.readings = []
                    self.processor.reset()
                    self.exposureLocked = false
                }
            }
        }
    }

    private func finish() {
        demoTask?.cancel()
        camera.stop()
        // Median over the second half of the window — the most stable part.
        guard let start = measureStart else { return }
        let stable = readings.filter { $0.0 - start > duration * 0.4 }.map { $0.1 }
        let source = stable.count >= 5 ? stable : readings.map { $0.1 }
        guard !source.isEmpty else {
            phase = .noFinger
            processor.reset()
            measureStart = nil
            progress = 0
            camera.start()
            return
        }
        let sorted = source.sorted()
        resultBPM = Int(sorted[sorted.count / 2].rounded())
        phase = .done
    }
}
