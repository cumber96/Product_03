//
//  WorkoutManager.swift
//  RunContent Watch App
//

import Combine
import Foundation
import HealthKit

/// 운동 기능의 흐름을 조율하는 최상위 관리자입니다.
///
/// 실제 데이터는 WorkoutStore에만 저장하며,
/// 시간 계산, HealthKit 세션, 기기 통신을 연결합니다.
@MainActor
final class WorkoutManager: ObservableObject {

    // MARK: - Store

    let store: WorkoutStore

    // MARK: - Components

    private let clock: WorkoutClock
    private let workoutSession: WorkoutSession
    private let connectivity: WorkoutConnectivity

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var previousState: WorkoutState = .idle

    // MARK: - Initialization

    init(
        store: WorkoutStore? = nil,
        clock: WorkoutClock? = nil,
        workoutSession: WorkoutSession? = nil,
        connectivity: WorkoutConnectivity? = nil
    ) {
        self.store = store ?? WorkoutStore()
        self.clock = clock ?? WorkoutClock()
        self.workoutSession = workoutSession ?? WorkoutSession()
        self.connectivity = connectivity ?? WorkoutConnectivity()

        bindComponents()
        configureSessionCallbacks()

        self.connectivity.activate()
    }

    // MARK: - Workout Control

    func startWorkout() {
        guard store.state.canStart else {
            return
        }

        store.clearError()

        Task {
            do {
                try await workoutSession.requestAuthorization()

                clock.reset()
                store.resetWorkout()

                try workoutSession.start()
            } catch {
                store.updateError(error)
            }
        }
    }

    func pauseWorkout() {
        workoutSession.pause()
    }

    func resumeWorkout() {
        workoutSession.resume()
    }

    func togglePause() {
        switch store.state {
        case .running:
            pauseWorkout()

        case .paused:
            resumeWorkout()

        default:
            break
        }
    }

    func endWorkout() {
        workoutSession.end()
    }

    func resetWorkout() {
        guard store.state == .ended || store.state == .idle else {
            return
        }

        clock.reset()
        workoutSession.reset()
        store.resetWorkout()
    }

    // MARK: - Binding

    private func bindComponents() {
        workoutSession.$state
            .removeDuplicates()
            .sink { [weak self] newState in
                self?.handleStateChange(newState)
            }
            .store(in: &cancellables)

        workoutSession.$lastError
            .sink { [weak self] error in
                guard let error else {
                    return
                }

                self?.store.updateError(error)
            }
            .store(in: &cancellables)

        clock.$elapsedTime
            .sink { [weak self] elapsedTime in
                self?.store.updateElapsedTime(elapsedTime)
            }
            .store(in: &cancellables)

        connectivity.$isReachable
            .sink { [weak self] isReachable in
                self?.store.updatePhoneReachability(isReachable)
            }
            .store(in: &cancellables)

        connectivity.$lastError
            .sink { [weak self] error in
                guard let error else {
                    return
                }

                self?.store.updateError(error)
            }
            .store(in: &cancellables)
    }

    private func configureSessionCallbacks() {
        workoutSession.onStatisticsUpdated = { [weak self] quantityType, statistics in
            self?.handleStatistics(
                quantityType: quantityType,
                statistics: statistics
            )
        }
    }

    // MARK: - State

    private func handleStateChange(_ newState: WorkoutState) {
        previousState = store.state
        store.updateState(newState)

        switch newState {
        case .idle:
            clock.reset()

        case .preparing:
            break

        case .running:
            if previousState == .paused {
                clock.resume()
            } else {
                clock.start()
            }

        case .paused:
            clock.pause()

        case .ending, .ended:
            clock.stop()
        }
    }

    // MARK: - HealthKit Statistics

    private func handleStatistics(
        quantityType: HKQuantityType,
        statistics: HKStatistics
    ) {
        switch quantityType.identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            updateHeartRate(from: statistics)

        case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue:
            updateDistance(from: statistics)

        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            updateActiveEnergy(from: statistics)

        default:
            break
        }
    }

    private func updateHeartRate(from statistics: HKStatistics) {
        guard let quantity = statistics.mostRecentQuantity() else {
            return
        }

        let unit = HKUnit.count().unitDivided(by: .minute())
        let value = quantity.doubleValue(for: unit)

        store.updateHeartRate(value)
    }

    private func updateDistance(from statistics: HKStatistics) {
        guard let quantity = statistics.sumQuantity() else {
            return
        }

        let value = quantity.doubleValue(for: .meter())

        store.updateDistance(value)
    }

    private func updateActiveEnergy(from statistics: HKStatistics) {
        guard let quantity = statistics.sumQuantity() else {
            return
        }

        let value = quantity.doubleValue(for: .kilocalorie())

        store.updateActiveEnergy(value)
    }
}
