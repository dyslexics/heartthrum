import AVFoundation
import Foundation

/// Drives the back camera + torch and emits per-frame mean color samples
/// from the center region. No frames are stored or leave the device.
final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    struct FrameSample {
        let time: Double
        let red: Double
        let green: Double
        let blue: Double
    }

    var onSample: ((FrameSample) -> Void)?

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "de.dvld.heartthrum.camera")
    private var device: AVCaptureDevice?
    private var configured = false

    static func requestAccess(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    func start() {
        queue.async { [self] in
            guard configure() else { return }
            if !session.isRunning { session.startRunning() }
            setTorch(on: true)
        }
    }

    func stop() {
        queue.async { [self] in
            setTorch(on: false)
            unlockExposure()
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Lock exposure + white balance once the finger is placed, for a stable signal.
    func lockExposure() {
        queue.async { [self] in
            guard let dev = device else { return }
            try? dev.lockForConfiguration()
            if dev.isExposureModeSupported(.locked) { dev.exposureMode = .locked }
            if dev.isWhiteBalanceModeSupported(.locked) { dev.whiteBalanceMode = .locked }
            dev.unlockForConfiguration()
        }
    }

    private func unlockExposure() {
        guard let dev = device else { return }
        try? dev.lockForConfiguration()
        if dev.isExposureModeSupported(.continuousAutoExposure) { dev.exposureMode = .continuousAutoExposure }
        if dev.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { dev.whiteBalanceMode = .continuousAutoWhiteBalance }
        dev.unlockForConfiguration()
    }

    private func configure() -> Bool {
        if configured { return true }
        guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: dev) else { return false }

        session.beginConfiguration()
        session.sessionPreset = .low

        guard session.canAddInput(input) else { session.commitConfiguration(); return false }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { session.commitConfiguration(); return false }
        session.addOutput(output)
        session.commitConfiguration()

        try? dev.lockForConfiguration()
        dev.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        dev.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
        dev.unlockForConfiguration()

        device = dev
        configured = true
        return true
    }

    private func setTorch(on: Bool) {
        guard let dev = device, dev.hasTorch else { return }
        try? dev.lockForConfiguration()
        if on {
            try? dev.setTorchModeOn(level: 0.3)
        } else {
            dev.torchMode = .off
        }
        dev.unlockForConfiguration()
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return }

        let w = CVPixelBufferGetWidth(pb)
        let h = CVPixelBufferGetHeight(pb)
        let bpr = CVPixelBufferGetBytesPerRow(pb)
        let ptr = base.assumingMemoryBound(to: UInt8.self)

        // Center 50% region, subsampled every 4th pixel — plenty for a mean.
        var r = 0.0, g = 0.0, b = 0.0, n = 0.0
        let x0 = w / 4, x1 = 3 * w / 4
        let y0 = h / 4, y1 = 3 * h / 4
        var y = y0
        while y < y1 {
            let row = y * bpr
            var x = x0
            while x < x1 {
                let o = row + x * 4
                b += Double(ptr[o])
                g += Double(ptr[o + 1])
                r += Double(ptr[o + 2])
                n += 1
                x += 4
            }
            y += 4
        }
        guard n > 0 else { return }

        let t = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        onSample?(FrameSample(time: t, red: r / n / 255.0, green: g / n / 255.0, blue: b / n / 255.0))
    }
}
