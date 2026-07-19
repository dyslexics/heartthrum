import Foundation

/// Turns the per-frame color samples into a heart rate estimate (PPG).
/// Pipeline per channel: bandpass 0.7–3.5 Hz (42–210 BPM) → peak detection
/// → inter-beat intervals → median BPM. Red and green channels are processed
/// in parallel and the channel with the more plausible signal wins.
final class PulseProcessor {

    struct Output {
        var fingerDetected: Bool
        var bpm: Double?
        /// 0…1, how trustworthy the current bpm is
        var quality: Double
        /// Normalized recent waveform for display (last ~4 s)
        var waveform: [Double]
    }

    private var green = ChannelChain()
    private var red = ChannelChain()
    private(set) var lastOutput = Output(fingerDetected: false, bpm: nil, quality: 0, waveform: [])

    func reset() {
        green = ChannelChain()
        red = ChannelChain()
        lastOutput = Output(fingerDetected: false, bpm: nil, quality: 0, waveform: [])
    }

    func process(_ s: CameraManager.FrameSample) -> Output {
        // Finger over torch-lit lens: red channel clearly dominates.
        // Ratio-based so it works in darkness AND daylight (ambient light
        // leaking around the fingertip adds green/blue in bright rooms).
        let dominance = s.red / max(0.01, max(s.green, s.blue))
        let fingerDetected = s.red > 0.18 && dominance > 1.35

        green.add(time: s.time, value: s.green)
        red.add(time: s.time, value: s.red)

        let best = green.score >= red.score ? green : red
        var out = Output(fingerDetected: fingerDetected,
                         bpm: best.bpm,
                         quality: fingerDetected ? best.quality : 0,
                         waveform: best.displayWaveform())
        if !fingerDetected { out.bpm = nil }
        lastOutput = out
        return out
    }
}

/// Filter + peak chain for a single color channel.
private struct ChannelChain {
    private var hp = Biquad.highpass(fc: 0.7, fs: 30)
    private var lp = Biquad.lowpass(fc: 3.5, fs: 30)

    private var times: [Double] = []
    private var filtered: [Double] = []
    private var peakTimes: [Double] = []
    private var warmupCount = 0

    var bpm: Double?
    var quality: Double = 0
    /// Pulsatility score used to pick the better channel
    var score: Double = 0

    mutating func add(time: Double, value: Double) {
        var v = hp.step(value)
        v = lp.step(v)
        warmupCount += 1
        // Discard filter warm-up transient
        if warmupCount < 45 { return }

        times.append(time)
        filtered.append(v)
        // Keep ~12 s of history
        while let first = times.first, time - first > 12 {
            times.removeFirst()
            filtered.removeFirst()
        }
        detectPeak(at: time)
        updateEstimate(now: time)
    }

    private mutating func detectPeak(at now: Double) {
        let n = filtered.count
        guard n >= 3 else { return }
        let a = filtered[n - 3], b = filtered[n - 2], c = filtered[n - 1]
        guard b > a, b >= c else { return }

        // Adaptive threshold: fraction of recent RMS over ~3 s
        let recent = filtered.suffix(90)
        let rms = sqrt(recent.reduce(0) { $0 + $1 * $1 } / Double(recent.count))
        guard rms > 1e-6, b > 0.5 * rms else { return }

        let peakTime = times[n - 2]
        if let last = peakTimes.last, peakTime - last < 0.30 { return } // > 200 BPM: reject
        peakTimes.append(peakTime)
        while let first = peakTimes.first, peakTime - first > 15 {
            peakTimes.removeFirst()
        }
    }

    private mutating func updateEstimate(now: Double) {
        // Pulsatility score for channel selection
        let recent = filtered.suffix(120)
        if recent.count > 30 {
            let mean = recent.reduce(0, +) / Double(recent.count)
            score = sqrt(recent.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(recent.count))
        }

        let peaks = peakTimes.filter { now - $0 <= 12 }
        guard peaks.count >= 4 else {
            bpm = nil
            quality = 0
            return
        }
        var ibis: [Double] = []
        for i in 1..<peaks.count {
            let d = peaks[i] - peaks[i - 1]
            if d >= 60.0 / 210.0 && d <= 60.0 / 42.0 { ibis.append(d) }
        }
        guard ibis.count >= 3 else {
            bpm = nil
            quality = 0
            return
        }
        let sorted = ibis.sorted()
        let median = sorted[sorted.count / 2]
        bpm = 60.0 / median

        // Quality from IBI regularity (coefficient of variation)
        let mean = ibis.reduce(0, +) / Double(ibis.count)
        let sd = sqrt(ibis.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(ibis.count))
        let cv = sd / mean
        quality = max(0, min(1, 1.2 - cv * 4))
    }

    func displayWaveform() -> [Double] {
        let recent = Array(filtered.suffix(120))
        guard let mx = recent.map({ abs($0) }).max(), mx > 1e-9 else { return [] }
        return recent.map { $0 / mx }
    }
}

/// RBJ cookbook biquad filter.
private struct Biquad {
    private var b0 = 0.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    static func lowpass(fc: Double, fs: Double, q: Double = 0.707) -> Biquad {
        let w = 2 * Double.pi * fc / fs
        let alpha = sin(w) / (2 * q)
        let cw = cos(w)
        let a0 = 1 + alpha
        var f = Biquad()
        f.b0 = ((1 - cw) / 2) / a0
        f.b1 = (1 - cw) / a0
        f.b2 = ((1 - cw) / 2) / a0
        f.a1 = (-2 * cw) / a0
        f.a2 = (1 - alpha) / a0
        return f
    }

    static func highpass(fc: Double, fs: Double, q: Double = 0.707) -> Biquad {
        let w = 2 * Double.pi * fc / fs
        let alpha = sin(w) / (2 * q)
        let cw = cos(w)
        let a0 = 1 + alpha
        var f = Biquad()
        f.b0 = ((1 + cw) / 2) / a0
        f.b1 = (-(1 + cw)) / a0
        f.b2 = ((1 + cw) / 2) / a0
        f.a1 = (-2 * cw) / a0
        f.a2 = (1 - alpha) / a0
        return f
    }

    mutating func step(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x
        y2 = y1; y1 = y
        return y
    }
}
