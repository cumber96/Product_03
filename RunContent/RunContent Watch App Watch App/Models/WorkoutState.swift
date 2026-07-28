//
//  WorkoutState.swift
//  RunContent
//

import Foundation

/// 운동 세션의 현재 진행 상태입니다.
///
/// 화면 표시, 타이머 동작, HealthKit 세션 제어의 기준이 됩니다.
/// 실제 운동 시작·일시정지·종료 처리는 WorkoutSession이 담당합니다.
enum WorkoutState: String, Equatable, Sendable {
    /// 운동을 시작하지 않은 초기 상태
    case idle

    /// 운동 시작을 준비하는 상태
    ///
    /// 카운트다운이나 HealthKit 세션 준비 과정에서 사용합니다.
    case preparing

    /// 운동이 진행 중인 상태
    case running

    /// 사용자가 운동을 일시정지한 상태
    case paused

    /// 운동 종료 처리가 진행 중인 상태
    ///
    /// HealthKit 저장과 세션 정리가 완료되기 전까지 사용합니다.
    case ending

    /// 운동이 완전히 종료된 상태
    case ended

    /// 운동이 현재 진행 중인지 여부
    var isActive: Bool {
        switch self {
        case .running, .paused:
            return true

        case .idle, .preparing, .ending, .ended:
            return false
        }
    }

    /// 운동 시간이 증가해야 하는 상태인지 여부
    var shouldAdvanceClock: Bool {
        self == .running
    }

    /// 운동을 시작할 수 있는 상태인지 여부
    var canStart: Bool {
        switch self {
        case .idle, .ended:
            return true

        case .preparing, .running, .paused, .ending:
            return false
        }
    }

    /// 운동을 일시정지할 수 있는 상태인지 여부
    var canPause: Bool {
        self == .running
    }

    /// 운동을 재개할 수 있는 상태인지 여부
    var canResume: Bool {
        self == .paused
    }

    /// 운동을 종료할 수 있는 상태인지 여부
    var canEnd: Bool {
        switch self {
        case .running, .paused:
            return true

        case .idle, .preparing, .ending, .ended:
            return false
        }
    }
}
