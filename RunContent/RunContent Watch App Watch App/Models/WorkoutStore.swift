//
//  WorkoutStore.swift
//  RunContent Watch App
//

import Combine
import Foundation

/// 운동 화면에서 사용하는 상태와 측정값을 한곳에서 관리합니다.
///
/// WorkoutManager만 값을 변경하고,
/// SwiftUI 화면은 이 객체의 데이터를 읽습니다.
@MainActor
final class WorkoutStore: ObservableObject {

    // MARK: - Workout State

    /// 현재 운동 진행 상태
    @Published private(set) var state: WorkoutState = .idle

    // MARK: - Workout Metrics

    /// 일시정지 시간을 제외한 운동 시간, 초
    @Published private(set) var elapsedTime: TimeInterval = 0

    /// 현재 심박수, BPM
    @Published private(set) var heartRate: Double = 0

    /// 누적 이동 거리, 미터
    @Published private(set) var distance: Double = 0

    /// 누적 활동 에너지, 킬로칼로리
    @Published private(set) var activeEnergy: Double = 0

    // MARK: - Connectivity

    /// iPhone 앱에 즉시 메시지를 보낼 수 있는지 여부
    @Published private(set) var isPhoneReachable = false

    // MARK: - Error

    /// 운동 또는 연결 과정에서 발생한 최근 오류
    @Published private(set) var lastError: Error?

    // MARK: - Derived Values

    /// 1km를 달리는 데 걸린 평균 시간, 초
    var averagePace: TimeInterval? {
        guard distance >= 1 else {
            return nil
        }

        return elapsedTime / (distance / 1_000)
    }

    // MARK: - State Update

    func updateState(_ state: WorkoutState) {
        self.state = state
    }

    // MARK: - Metrics Update

    func updateElapsedTime(_ value: TimeInterval) {
        elapsedTime = max(0, value)
    }

    func updateHeartRate(_ value: Double) {
        heartRate = max(0, value)
    }

    func updateDistance(_ value: Double) {
        distance = max(0, value)
    }

    func updateActiveEnergy(_ value: Double) {
        activeEnergy = max(0, value)
    }

    // MARK: - Connectivity Update

    func updatePhoneReachability(_ isReachable: Bool) {
        isPhoneReachable = isReachable
    }

    // MARK: - Error Update

    func updateError(_ error: Error?) {
        lastError = error
    }

    func clearError() {
        lastError = nil
    }

    // MARK: - Reset

    /// 새로운 운동을 시작하기 전 측정값을 초기화합니다.
    ///
    /// 연결 상태는 운동 데이터가 아니므로 유지합니다.
    func resetWorkout() {
        state = .idle
        elapsedTime = 0
        heartRate = 0
        distance = 0
        activeEnergy = 0
        lastError = nil
    }
}
