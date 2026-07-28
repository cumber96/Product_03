import Foundation
import HealthKit
import Combine

@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()

    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    @Published private(set) var isWorkoutRunning = false
    @Published private(set) var statusMessage = "운동 시작 전"

    private func makeWorkoutConfiguration() -> HKWorkoutConfiguration {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .indoor
        return configuration
    }

    func startWorkout() {
        guard !isWorkoutRunning else { return }

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

            let startDate = Date()

            session.startActivity(with: startDate)

            builder.beginCollection(withStart: startDate) { [weak self] success, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.statusMessage = "운동 시작 실패: \(error.localizedDescription)"
                        return
                    }

                    self.isWorkoutRunning = success
                    self.statusMessage = success ? "러닝 중" : "운동을 시작하지 못했습니다."
                }
            }
        } catch {
            statusMessage = "세션 생성 실패: \(error.localizedDescription)"
        }
    }

    func stopWorkout() {
        guard isWorkoutRunning,
              let workoutSession,
              let workoutBuilder
        else {
            return
        }

        let endDate = Date()

        workoutSession.end()

        workoutBuilder.endCollection(withEnd: endDate) { [weak self] success, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.statusMessage = "운동 종료 실패: \(error.localizedDescription)"
                    return
                }

                guard success else {
                    self.statusMessage = "운동을 종료하지 못했습니다."
                    return
                }

                workoutBuilder.finishWorkout { workout, error in
                    Task { @MainActor in
                        if let error {
                            self.statusMessage = "운동 저장 실패: \(error.localizedDescription)"
                        } else if workout != nil {
                            self.statusMessage = "운동이 저장되었습니다."
                        } else {
                            self.statusMessage = "운동 저장 결과를 확인하지 못했습니다."
                        }

                        self.isWorkoutRunning = false
                        self.workoutSession = nil
                        self.workoutBuilder = nil
                    }
                }
            }
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
            statusMessage = "운동 오류: \(error.localizedDescription)"
            isWorkoutRunning = false
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
        // 다음 단계에서 심박수, 거리, 칼로리를 처리한다.
    }
}
