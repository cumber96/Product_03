//
//  WorkoutClock.swift
//  RunContent Watch App
//

import Combine
import Foundation

/// 운동의 경과 시간만 관리합니다.
///
/// HealthKit 세션이나 운동 상태는 알지 못하며,
/// 시작·일시정지·재개·종료에 따른 시간 계산만 담당합니다.
@MainActor
final class WorkoutClock: ObservableObject {

    /// 일시정지 시간을 제외한 운동 경과 시간
    @Published private(set) var elapsedTime: TimeInterval = 0

    /// 현재 시간이 증가하고 있는지 여부
    @Published private(set) var isRunning = false

    /// 이전 실행 구간까지 누적된 시간
    private var accumulatedTime: TimeInterval = 0

    /// 현재 실행 구간이 시작된 시각
    private var runningStartDate: Date?

    /// 화면 갱신용 타이머
    private var updateTimer: Timer?

    // MARK: - Public Methods

    /// 새로운 운동 시간을 처음부터 시작합니다.
    func start() {
        reset()
        resume()
    }

    /// 현재까지의 시간을 유지하고 일시정지합니다.
    func pause() {
        guard isRunning else {
            return
        }

        updateElapsedTime()

        accumulatedTime = elapsedTime
        runningStartDate = nil
        isRunning = false

        invalidateTimer()
    }

    /// 일시정지된 시점부터 시간을 다시 측정합니다.
    func resume() {
        guard !isRunning else {
            return
        }

        runningStartDate = Date()
        isRunning = true

        startUpdateTimer()
        updateElapsedTime()
    }

    /// 현재 시간을 유지한 채 측정을 종료합니다.
    func stop() {
        pause()
    }

    /// 모든 시간 정보를 초기 상태로 되돌립니다.
    func reset() {
        invalidateTimer()

        elapsedTime = 0
        accumulatedTime = 0
        runningStartDate = nil
        isRunning = false
    }

    // MARK: - Private Methods

    private func startUpdateTimer() {
        invalidateTimer()

        let timer = Timer(
            timeInterval: 0.2,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedTime()
            }
        }

        timer.tolerance = 0.05

        RunLoop.main.add(
            timer,
            forMode: .common
        )

        updateTimer = timer
    }

    private func updateElapsedTime() {
        guard
            isRunning,
            let runningStartDate
        else {
            return
        }

        let currentInterval = Date().timeIntervalSince(runningStartDate)

        elapsedTime = accumulatedTime + max(0, currentInterval)
    }

    private func invalidateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}
