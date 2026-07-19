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

    var phase: Phase = .idle
    var liveBPM: Int?
    var quality: Double = 0
    var progress: Double = 0
    var waveform: [Double] = []
    var resultBPM: Int?
    /// TestFlight diagnostics line (frame count + color means) — remove before App Store submission
    var debugLine: String = "–"

    private let camera = CameraManager()
    private let processor = PulseProcessor()

    private var measureStart: Double?
    private var lastFingerSeen: Double?
    private var exposureLocked = false
    private var frameCount = 0
    /// (time, bpm) readings collected during the measurement window
    private var readings: [(Double, Double)] = []

    init() {
        camera.onSample = { [weak self] sample in
            self?.handle(sample)
        }
    }

    func start() {
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

    func cancel() {
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

            self.frameCount += 1
            let dominance = sample.red / max(0.01, max(sample.green, sample.blue))
            self.debugLine = String(format: "f%d  R %.2f  G %.2f  B %.2f  d%.2f  %@",
                                    self.frameCount, sample.red, sample.green, sample.blue,
                                    dominance, out.fingerDetected ? "FINGER✓" : "–")
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
                    self.progress = min(1, (now - start) / Self.measureDuration)
                    if now - start >= Self.measureDuration {
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
        camera.stop()
        // Median over the second half of the window — the most stable part.
        guard let start = measureStart else { return }
        let stable = readings.filter { $0.0 - start > Self.measureDuration * 0.4 }.map { $0.1 }
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
