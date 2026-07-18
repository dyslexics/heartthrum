# Heartthrum — Spec (2026-07-18)

Kostenlose Puls-App für Wellness & Wohlbefinden. Keine Werbung, keine Käufe, keine Accounts, kein Tracking, kein Netzwerkzugriff. Vorbild: Cardiio — aber ohne dessen Premium-Upsells.

## Eckdaten
- **Name:** Heartthrum · **Bundle:** de.dvld.heartthrum · **Team:** FQZ492F2YC (DVLD)
- **Domain:** heartthrum.com (Registrierung offen; Mario schrieb „hearththrum.com" — beide frei, Empfehlung: heartthrum.com passend zum App-Namen)
- **Kategorie:** Health & Fitness · **Preis:** kostenlos · **Sprachen:** DE + EN
- **Kein Medizinprodukt** — Disclaimer im Onboarding + Einstellungen
- **Privacy Label:** „Data Not Collected" (kein Netzwerkzugriff)
- **Technik:** Nativ SwiftUI, iOS 17+, SwiftData, Swift Charts, xcodegen, Build via fastlane auf Mac Studio

## Messverfahren (PPG)
Finger auf Rückkamera + Torch (Level 0.3), 40 s. Pro Frame mittlere R/G/B-Helligkeit (Zentrum, BGRA). Bandpass 0,7–3,5 Hz (Biquad HP+LP, fs 30), Peak-Detection mit adaptiver Schwelle (0,5×RMS, min. Abstand 0,3 s), Median-BPM aus IBIs. Rot- und Grün-Kanal parallel, pulsatilerer Kanal gewinnt. Qualität aus IBI-Variationskoeffizient. Exposure/WB-Lock 1,5 s nach Fingerauflage. Ergebnis = Median der zweiten Messhälfte.

Apple-Gotchas: kein SpO2/Blutdruck per Kamera (1.4.1-Ablehnung); Verlauf + Atemübung schützen gegen 4.2 (Minimum Functionality).

## Screens
1. **Messen** — Fortschrittsring, Live-BPM, Pulskurve (Canvas), Signalqualität; danach Speichern mit Kontext-Tag (In Ruhe/Nach Bewegung/Morgens/Abends) + Stimmung (3 Stufen)
2. **Verlauf** — SwiftData, Chart Tag/Woche/Monat, Ø/Min/Max, Liste mit Swipe-Delete
3. **Atmen** — geführte Atmung 4 s ein / 6 s aus (6/min), 1/3/5 Min, animierter Kreis
4. **Einstellungen** — Apple-Health-Export (Toggle, nur Schreiben von Herzfrequenz), Disclaimer, Privacy-Link, Version

## Offene Punkte
- Domain registrieren (Mario), Privacy-Page + Mini-Landingpage hosten
- App-Icon 1024 px, Screenshots, ASC-Metadaten DE/EN, Age Rating
- PPG-Genauigkeit real testen (gegen Referenz), Parameter tunen
