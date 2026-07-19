# Heartthrum (iOS)

**A completely free heart rate app. No ads, no premium, no in-app purchases, no data collection. Ever.**

Heartthrum measures your pulse using the iPhone camera (photoplethysmography, PPG): place your fingertip on the rear camera lens, and the app detects tiny color changes in your skin caused by your heartbeat.

Website: [heartthrum.com](https://heartthrum.com) · [App Store](https://apps.apple.com/app/id6792297139)

The Android version lives in its own repository: [heartthrum-android](../../../heartthrum-android)

## Features

- **Measure** — 40-second PPG measurement with live pulse curve, quality indicator, and optional tag/mood
- **History** — day/week/month charts of your measurements (Swift Charts, stored locally with SwiftData)
- **Breathe** — guided breathing exercise (4s in / 6s out)
- **Apple Health export** — optional, write-only (heart rate samples)
- Languages: English and German
- **No network access.** The app collects nothing and sends nothing. Privacy label: "Data Not Collected".

## Not a medical device

Heartthrum is a wellness app. It is **not** a medical device and must not be used for diagnosis, treatment, or monitoring of any medical condition. Camera-based pulse measurement cannot measure blood pressure or blood oxygen.

## How it works

- `Sources/PPG/CameraManager.swift` — rear camera at 30 fps (BGRA), torch on, center ROI averaging of R/G/B; exposure locks 1.5 s after finger placement
- `Sources/PPG/PulseProcessor.swift` — biquad band-pass 0.7–3.5 Hz, adaptive peak detection, median BPM from inter-beat intervals; red and green channels processed in parallel, the more pulsatile one wins. Finger detection is red-dominance based (`r > 0.18 && r/max(g,b) > 1.35`), which works in daylight and darkness
- `Sources/PPG/MeasureViewModel.swift` — 40 s measurement, result = median of the second half

## Building

Requirements: Xcode 16+, [xcodegen](https://github.com/yonaskolb/XcodeGen)

```bash
xcodegen generate
xcodebuild -scheme Heartthrum \
  -destination "generic/platform=iOS Simulator" \
  build CODE_SIGNING_ALLOWED=NO
```

Open `Heartthrum.xcodeproj` in Xcode to run on the simulator. The simulator has no camera; use launch arguments for demo data:

- `-demoData` — seeds the history with sample measurements
- `-demoMeasure` — synthetic PPG signal through the real processing engine
- `-tab N` — jump straight to tab N (skips onboarding)

For device builds you need your own signing setup (the project uses manual signing via `project.yml`).

## License

[GPL-3.0](LICENSE) — © Mario Engel

Free forever. If you fork it, keep it free.
