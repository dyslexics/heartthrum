import SwiftUI
import AVFoundation

/// Shows which lens to cover on triple-camera iPhones (Pro/Pro Max):
/// the main wide camera is the BOTTOM-LEFT lens, next to it the flash.
/// On single/dual-lens phones a fingertip covers everything anyway,
/// so the hint is only shown when a telephoto + ultra-wide exist.
struct CameraHintView: View {
    static let isTripleCamera: Bool = {
        // "-forceLensHint" is a screenshot/demo hook (simulator has no cameras)
        ProcessInfo.processInfo.arguments.contains("-forceLensHint") ||
            (AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) != nil &&
             AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil)
    }()

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                // Camera module
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .frame(width: 150, height: 150)

                lens(x: -35, y: -35)                       // ultra wide (top left)
                lens(x: -35, y: 35, highlighted: true)     // MAIN wide (bottom left)
                lens(x: 38, y: 0)                          // telephoto (right)

                // Flash (top right)
                Circle()
                    .fill(Color.yellow.opacity(0.8))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color.pink, lineWidth: 2.5))
                    .offset(x: 38, y: -42)

                // Pulsing highlight ring around the correct lens
                Circle()
                    .stroke(Color.pink, lineWidth: 3)
                    .frame(width: 62, height: 62)
                    .scaleEffect(pulse ? 1.15 : 1.0)
                    .opacity(pulse ? 0.4 : 1.0)
                    .offset(x: -35, y: 35)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)

                // Fingertip suggestion covering lens + flash
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.pink)
                    .offset(x: 8, y: 78)
            }
            .onAppear { pulse = true }

            Text("Use the bottom-left lens (main camera) and the flash.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func lens(x: CGFloat, y: CGFloat, highlighted: Bool = false) -> some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: 46, height: 46)
            Circle()
                .fill(Color(.systemGray2))
                .frame(width: 30, height: 30)
            Circle()
                .fill(highlighted ? Color.pink.opacity(0.55) : Color(.systemGray).opacity(0.6))
                .frame(width: 16, height: 16)
        }
        .offset(x: x, y: y)
    }
}

#Preview {
    CameraHintView()
}
