import Foundation
import HealthKit

struct HealthWorkoutSession: Identifiable, Hashable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let activityName: String
    let activityTypeRawValue: UInt
    let sourceName: String?
    
    var durationMinutes: Int {
        max(0, Int(endDate.timeIntervalSince(startDate) / 60.0))
    }
}

final class HealthKitManager {
    static let shared = HealthKitManager()
    
    private let store = HKHealthStore()
    
    private init() {}
    
    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    func requestWorkoutReadAuthorization() async -> Bool {
        guard isHealthDataAvailable else { return false }
        guard let workoutType = HKObjectType.workoutType() as HKObjectType? else { return false }
        
        do {
            try await store.requestAuthorization(toShare: [], read: [workoutType])
            return true
        } catch {
            return false
        }
    }
    
    func fetchWorkouts(from start: Date, to end: Date) async -> [HealthWorkoutSession] {
        guard isHealthDataAvailable else { return [] }
        
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                let mapped: [HealthWorkoutSession] = workouts.map { w in
                    HealthWorkoutSession(
                        id: w.uuid,
                        startDate: w.startDate,
                        endDate: w.endDate,
                        activityName: Self.name(for: w.workoutActivityType),
                        activityTypeRawValue: w.workoutActivityType.rawValue,
                        sourceName: w.sourceRevision.source.name
                    )
                }
                continuation.resume(returning: mapped)
            }
            self.store.execute(query)
        }
    }
    
    private static func name(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .traditionalStrengthTraining: return "Strength"
        case .functionalStrengthTraining: return "Strength"
        case .yoga: return "Yoga"
        case .highIntensityIntervalTraining: return "HIIT"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .stairClimbing: return "Stairs"
        case .mindAndBody: return "Mind & Body"
        case .other: return "Workout"
        default:
            return "Workout"
        }
    }
}

