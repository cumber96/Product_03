import Foundation
import HealthKit
import Combine

@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()

    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var timer: Timer?

    private var accumulatedElapsedTime: TimeInterval = 0
    private var lastResumeDate: Date?
    private var isFinishingWorkout = false

    @Published private(set) var isWorkoutRunning = false
    @Published private(set) var isWorkoutPaused = false
    @Published private(set) var isWorkoutEnding = false
    @Published private(set) var statusMessage = "운동 시작 전"

    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var distance: Double = 0
    @Published private(set) var activeEnergy: Double = 0

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

    var formattedAveragePace: String {
        guard distance > 0 else {
            return "--'--\"/km"
        }

        let distanceInKilometers = distance / 1000
        let secondsPerKilometer =
            elapsedTime / distanceInKilometers

        guard secondsPerKilometer.isFinite,
              secondsPerKilometer > 0
        else {
            return "--'--\"/km"
        }

        let roundedSeconds =
            Int(secondsPerKilometer.rounded())

        let minutes = roundedSeconds / 60
        let seconds = roundedSeconds % 60

        return String(
            format: "%d'%02d\"/km",
            minutes,
            seconds
        )
    }

    private func makeWorkoutConfiguration()
        -> HKWorkoutConfiguration {

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .indoor

        return configuration
    }

    // MARK: - 운동 시작

    func startWorkout() {
        guard !isWorkoutRunning,
              !isWorkoutEnding
        else {
            return
        }

        resetMetrics()

        do {
            let configuration =
                makeWorkoutConfiguration()

            let session = try HKWorkoutSession(
                healthStore: healthStore,
                configuration: configuration
            )

            let builder =
                session.associatedWorkoutBuilder()

            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            session.delegate = self
            builder.delegate = self

            workoutSession = session
            workoutBuilder = builder

            let workoutStartDate = Date()

            accumulatedElapsedTime = 0
            lastResumeDate = workoutStartDate
            isWorkoutPaused = false
            isWorkoutEnding = false
            isFinishingWorkout = false

            session.startActivity(
                with: workoutStartDate
            )

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
                    self.isWorkoutPaused = false
                    self.statusMessage = "러닝 중"
                    self.startTimer()
                }
            }
        } catch {
            statusMessage =
                "세션 생성 실패: \(error.localizedDescription)"
        }
    }

    // MARK: - 운동 일시정지

    func pauseWorkout() {
        guard isWorkoutRunning,
              !isWorkoutPaused,
              !isWorkoutEnding,
              let workoutSession
        else {
            return
        }

        updateElapsedTime()
        accumulatedElapsedTime = elapsedTime
        lastResumeDate = nil

        stopTimer()

        isWorkoutPaused = true
        statusMessage = "일시정지"

        workoutSession.pause()
    }

    // MARK: - 운동 재개

    func resumeWorkout() {
        guard isWorkoutRunning,
              isWorkoutPaused,
              !isWorkoutEnding,
              let workoutSession
        else {
            return
        }

        lastResumeDate = Date()

        isWorkoutPaused = false
        statusMessage = "러닝 중"

        workoutSession.resume()
        startTimer()
    }

    // MARK: - 운동 종료 요청

    func stopWorkout() {
        guard isWorkoutRunning,
              !isWorkoutEnding,
              !isFinishingWorkout,
              let workoutSession
        else {
            return
        }

        updateElapsedTime()
        accumulatedElapsedTime = elapsedTime
        lastResumeDate = nil

        stopTimer()

        isWorkoutEnding = true
        statusMessage = "운동 저장 중"

        // 실제 저장은 세션이 .ended 상태가 된 뒤 실행
        workoutSession.end()
    }

    // MARK: - 운동 저장

    private func finishWorkout(at endDate: Date) {
        guard !isFinishingWorkout,
              let workoutBuilder
        else {
            return
        }

        isFinishingWorkout = true

        workoutBuilder.endCollection(
            withEnd: endDate
        ) { [weak self] success, error in
            Task { @MainActor in
                guard let self else {
                    return
                }

                if let error {
                    self.completeWorkoutWithError(
                        "운동 종료 실패: \(error.localizedDescription)"
                    )
                    return
                }

                guard success else {
                    self.completeWorkoutWithError(
                        "운동을 종료하지 못했습니다."
                    )
                    return
                }

                workoutBuilder.finishWorkout {
                    workout,
                    error in

                    Task { @MainActor in
                        if let error {
                            self.completeWorkoutWithError(
                                "운동 저장 실패: \(error.localizedDescription)"
                            )
                        } else if workout != nil {
                            self.completeWorkout(
                                message: "운동이 저장되었습니다."
                            )
                        } else {
                            self.completeWorkoutWithError(
                                "운동 저장 결과를 확인하지 못했습니다."
                            )
                        }
                    }
                }
            }
        }
    }

    private func completeWorkout(message: String) {
        statusMessage = message
        clearWorkoutSession()
    }

    private func completeWorkoutWithError(
        _ message: String
    ) {
        statusMessage = message
        clearWorkoutSession()
    }

    private func clearWorkoutSession() {
        stopTimer()

        isWorkoutRunning = false
        isWorkoutPaused = false
        isWorkoutEnding = false
        isFinishingWorkout = false

        workoutSession = nil
        workoutBuilder = nil

        lastResumeDate = nil
        accumulatedElapsedTime = 0
    }

    // MARK: - 시간 계산

    private func startTimer() {
        timer?.invalidate()

        timer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedTime()
            }
        }
    }

    private func updateElapsedTime() {
        guard let lastResumeDate else {
            elapsedTime = accumulatedElapsedTime
            return
        }

        elapsedTime =
            accumulatedElapsedTime
            + Date().timeIntervalSince(lastResumeDate)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - 초기화

    private func resetMetrics() {
        elapsedTime = 0
        heartRate = 0
        distance = 0
        activeEnergy = 0

        accumulatedElapsedTime = 0
        lastResumeDate = nil

        isWorkoutPaused = false
        isWorkoutEnding = false
        isFinishingWorkout = false
    }

    // MARK: - HealthKit 데이터

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
        case HKQuantityTypeIdentifier
            .heartRate.rawValue:

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

// MARK: - HKWorkoutSessionDelegate

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
                if !isWorkoutEnding {
                    isWorkoutRunning = true
                    isWorkoutPaused = false
                    statusMessage = "러닝 중"
                }

            case .paused:
                if !isWorkoutEnding {
                    isWorkoutPaused = true
                    statusMessage = "일시정지"
                }

            case .ended:
                finishWorkout(at: date)

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

            clearWorkoutSession()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

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
