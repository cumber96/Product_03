//
//  WorkoutSession.swift
//  RunContent Watch App
//

import Combine
import Foundation
import HealthKit

/// HealthKit 운동 세션의 생성과 생명주기만 관리합니다.
///
/// 화면, 운동 시간, 측정값 저장 방식은 알지 못합니다.
/// 수집된 HealthKit 통계는 상위 객체인 WorkoutManager로 전달합니다.
@MainActor
final class WorkoutSession: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var state: WorkoutState = .idle

    @Published private(set) var lastError: Error?

    // MARK: - Event Handlers

    /// HealthKit 측정값이 갱신될 때 호출됩니다.
    var onStatisticsUpdated: ((HKQuantityType, HKStatistics) -> Void)?

    // MARK: - HealthKit

    private let healthStore = HKHealthStore()

    private var session: HKWorkoutSession?

    private var builder: HKLiveWorkoutBuilder?

    // MARK: - Authorization

    /// 운동 기록에 필요한 HealthKit 권한을 요청합니다.
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw WorkoutSessionError.healthDataUnavailable
        }

        let workoutType = HKObjectType.workoutType()

        guard
            let heartRateType = HKObjectType.quantityType(
                forIdentifier: .heartRate
            ),
            let distanceType = HKObjectType.quantityType(
                forIdentifier: .distanceWalkingRunning
            ),
            let activeEnergyType = HKObjectType.quantityType(
                forIdentifier: .activeEnergyBurned
            )
        else {
            throw WorkoutSessionError.requiredTypeUnavailable
        }

        let typesToShare: Set<HKSampleType> = [
            workoutType
        ]

        let typesToRead: Set<HKObjectType> = [
            heartRateType,
            distanceType,
            activeEnergyType
        ]

        try await healthStore.requestAuthorization(
            toShare: typesToShare,
            read: typesToRead
        )
    }

    // MARK: - Session Control

    /// 실내 달리기 운동 세션을 준비하고 시작합니다.
    func start() throws {
        guard state.canStart else {
            return
        }

        state = .preparing
        lastError = nil

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .indoor

        let session = try HKWorkoutSession(
            healthStore: healthStore,
            configuration: configuration
        )

        let builder = session.associatedWorkoutBuilder()

        session.delegate = self
        builder.delegate = self

        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        self.session = session
        self.builder = builder

        let startDate = Date()

        session.startActivity(with: startDate)

        builder.beginCollection(
            withStart: startDate
        ) { [weak self] success, error in
            guard let self else {
                return
            }

            if let error {
                Task { @MainActor in
                    self.handleError(error)
                }

                return
            }

            guard success else {
                Task { @MainActor in
                    self.handleError(
                        WorkoutSessionError.collectionFailed
                    )
                }

                return
            }
        }
    }

    /// 현재 운동을 일시정지합니다.
    func pause() {
        guard state.canPause else {
            return
        }

        session?.pause()
    }

    /// 일시정지된 운동을 다시 시작합니다.
    func resume() {
        guard state.canResume else {
            return
        }

        session?.resume()
    }

    /// 현재 운동을 종료합니다.
    func end() {
        guard state.canEnd else {
            return
        }

        state = .ending
        session?.end()
    }

    /// 종료된 세션 정보를 초기 상태로 정리합니다.
    func reset() {
        guard state == .ended || state == .idle else {
            return
        }

        session = nil
        builder = nil
        lastError = nil
        state = .idle
    }

    // MARK: - Private Methods

    private func finishWorkout() {
        guard let builder else {
            state = .ended
            return
        }

        let endDate = Date()

        builder.endCollection(
            withEnd: endDate
        ) { [weak self] success, error in
            guard let self else {
                return
            }

            if let error {
                Task { @MainActor in
                    self.handleError(error)
                }

                return
            }

            guard success else {
                Task { @MainActor in
                    self.handleError(
                        WorkoutSessionError.collectionFailed
                    )
                }

                return
            }

            builder.finishWorkout { [weak self] _, error in
                guard let self else {
                    return
                }

                Task { @MainActor in
                    if let error {
                        self.handleError(error)
                        return
                    }

                    self.state = .ended
                }
            }
        }
    }

    private func handleError(_ error: Error) {
        lastError = error
        state = .ended
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutSession: HKWorkoutSessionDelegate {

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            switch toState {
            case .notStarted:
                self.state = .preparing

            case .running:
                self.state = .running

            case .paused:
                self.state = .paused

            case .ended:
                self.finishWorkout()

            case .prepared:
                self.state = .preparing

            case .stopped:
                self.state = .ending

            @unknown default:
                break
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.handleError(error)
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutSession: HKLiveWorkoutBuilderDelegate {

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            for sampleType in collectedTypes {
                guard
                    let quantityType = sampleType as? HKQuantityType,
                    let statistics = workoutBuilder.statistics(
                        for: quantityType
                    )
                else {
                    continue
                }

                self.onStatisticsUpdated?(
                    quantityType,
                    statistics
                )
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(
        _ workoutBuilder: HKLiveWorkoutBuilder
    ) {
        // 운동 이벤트 처리는 추후 확장합니다.
    }
}

// MARK: - Errors

enum WorkoutSessionError: LocalizedError {

    case healthDataUnavailable
    case requiredTypeUnavailable
    case collectionFailed

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "이 기기에서는 HealthKit을 사용할 수 없습니다."

        case .requiredTypeUnavailable:
            return "운동에 필요한 HealthKit 데이터 형식을 찾을 수 없습니다."

        case .collectionFailed:
            return "운동 데이터 수집을 시작하거나 종료하지 못했습니다."
        }
    }
}
