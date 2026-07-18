import Foundation
import HealthKit

final class HealthManager {
    static let shared = HealthManager()
    private let store = HKHealthStore()

    var available: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        guard available else { completion(false); return }
        let type = HKQuantityType(.heartRate)
        store.requestAuthorization(toShare: [type], read: []) { ok, _ in
            DispatchQueue.main.async { completion(ok) }
        }
    }

    func saveHeartRate(bpm: Int, date: Date) {
        guard available else { return }
        let type = HKQuantityType(.heartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())
        let sample = HKQuantitySample(type: type,
                                      quantity: HKQuantity(unit: unit, doubleValue: Double(bpm)),
                                      start: date, end: date)
        store.save(sample) { _, _ in }
    }
}
