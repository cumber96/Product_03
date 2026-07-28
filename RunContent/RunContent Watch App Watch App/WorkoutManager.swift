import Foundation
import HealthKit
import Combine

@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()

    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var startDate: Date?

    @Published private(set) var isWorkoutRunning = false
    @Published private(set) var statusMessage = "운동 시작 전"

    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var distance: Double = 0
    @Published private(set) var activeEnergy: Double = 0

    // 경과 시간을 00:00 또는 00:00:00 형식으로 변환
    var formattedElapsedTime: String {
        let totalSeconds = Int(elapsedTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(
                format: "%02d:%02d:%02d",
                hours,
                minutes,
                seconds
            )
        }

        return String(
            format: "%02d:%02d",
            minutes,
            seconds
        )
    }

    // 평균 페이스를 분'초"/km 형식으로 변환
    var formattedAveragePace: String {
        guard distance > 0 else {
            return "--'--\"/km"
        }

        let distanceInKilometers = distance / 1000
        let secondsPerKilometer = elapsedTime / distanceInKilometers

        guard secondsPerKilometer.isFinite,
              secondsPerKilometer > 0
        else {
            return "--'--\"/km"
        }

        let roundedSeconds = Int(secondsPerKilometer.rounded())
        let minutes = roundedSeconds / 60
        let seconds = roundedSeconds % 60

        return String(
            format: "%d'%02d\"/km",
            minutes,
            seconds
        )
    }

    private func makeWorkoutConfiguration() -> HKWorkoutConfiguration {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .indoor

        return configuration
    }

    func startWorkout() {
        guard !isWorkoutRunning else {
            return
        }

        resetMetrics()

        do {
            let configuration = makeWorkoutConfiguration()

            let session = try HKWorkoutSession(
                healthStore: healthStore,
                configuration: configuration
            )

            let builder = session.associatedWorkoutBuilder()

            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            session.delegate = self
            builder.delegate = self

            workoutSession = session
            workoutBuilder = builder

            let workoutStartDate = Date()
            startDate = workoutStartDate

            session.startActivity(with: workoutStartDate)

            builder.beginCollection(
                withStart: workoutStartDate
            ) { [weak self] success, error in
                Task { @MainActor in
                    guard let self else {
                        return
                    }

                    if let error {
                        self.statusMessage =
                            "운동 시작 실패: \(error.localizedDescription)"
                        return
                    }

                    guard success else {
                        self.statusMessage =
                            "운동을 시작하지 못했습니다."
                        return
                    }

                    self.isWorkoutRunning = true
                    self.statusMessage = "러닝 중"
                    self.startTimer()
                }
            }
        } catch {
            statusMessage =
                "세션 생성 실패: \(error.localizedDescription)"
        }
    }

    func stopWorkout() {
        guard isWorkoutRunning,
              let workoutSession,
              let workoutBuilder
        else {
            return
        }

        stopTimer()

        let endDate = Date()

        workoutSession.end()

        workoutBuilder.endCollection(
            withEnd: endDate
        ) { [weak self] success, error in
            Task { @MainActor in
                guard let self else {
                    return
                }

                if let error {
                    self.statusMessage =
                        "운동 종료 실패: \(error.localizedDescription)"
                    return
                }

                guard success else {
                    self.statusMessage =
                        "운동을 종료하지 못했습니다."
                    return
                }

                workoutBuilder.finishWorkout { workout, error in
                    Task { @MainActor in
                        if let error {
                            self.statusMessage =
                                "운동 저장 실패: \(error.localizedDescription)"
                        } else if workout != nil {
                            self.statusMessage =
                                "운동이 저장되었습니다."
                        } else {
                            self.statusMessage =
                                "운동 저장 결과를 확인하지 못했습니다."
                        }

                        self.isWorkoutRunning = false
                        self.workoutSession = nil
                        self.workoutBuilder = nil
                        self.startDate = nil
                    }
                }
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()

        timer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      let startDate = self.startDate
                else {
                    return
                }

                self.elapsedTime =
                    Date().timeIntervalSince(startDate)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func resetMetrics() {
        elapsedTime = 0
        heartRate = 0
        distance = 0
        activeEnergy = 0
    }

    private func updateStatistics(
        for quantityType: HKQuantityType,
        builder: HKLiveWorkoutBuilder
    ) {
        guard let statistics =
                builder.statistics(for: quantityType)
        else {
            return
        }

        switch quantityType.identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            let unit = HKUnit
                .count()
                .unitDivided(by: .minute())

            heartRate = statistics
                .mostRecentQuantity()?
                .doubleValue(for: unit) ?? 0

        case HKQuantityTypeIdentifier
            .distanceWalkingRunning.rawValue:

            distance = statistics
                .sumQuantity()?
                .doubleValue(for: .meter()) ?? 0

        case HKQuantityTypeIdentifier
            .activeEnergyBurned.rawValue:

            activeEnergy = statistics
                .sumQuantity()?
                .doubleValue(for: .kilocalorie()) ?? 0

        default:
            break
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            switch toState {
            case .running:
                statusMessage = "러닝 중"

            case .ended:
                isWorkoutRunning = false
                stopTimer()

            case .paused:
                statusMessage = "일시정지"

            default:
                break
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            statusMessage =
                "운동 오류: \(error.localizedDescription)"

            isWorkoutRunning = false
            stopTimer()
        }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(
        _ workoutBuilder: HKLiveWorkoutBuilder
    ) {
    }

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            for sampleType in collectedTypes {
                guard let quantityType =
                        sampleType as? HKQuantityType
                else {
                    continue
                }

                updateStatistics(
                    for: quantityType,
                    builder: workoutBuilder
                )
            }
        }
    }
}
