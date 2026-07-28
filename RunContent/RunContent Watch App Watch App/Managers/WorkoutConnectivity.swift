//
//  WorkoutConnectivity.swift
//  RunContent Watch App
//

import Combine
import Foundation
import WatchConnectivity

/// Apple Watch와 iPhone 사이의 통신을 관리합니다.
///
/// 운동 로직이나 HealthKit은 알지 못하며,
/// 연결 상태 확인과 데이터 전송만 담당합니다.
@MainActor
final class WorkoutConnectivity: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// WatchConnectivity 세션 활성화 여부
    @Published private(set) var isActivated = false

    /// iPhone 앱에 즉시 메시지를 보낼 수 있는 상태인지 여부
    @Published private(set) var isReachable = false

    /// 마지막 통신 오류
    @Published private(set) var lastError: Error?

    // MARK: - Event Handlers

    /// iPhone에서 메시지를 받았을 때 호출됩니다.
    var onMessageReceived: (([String: Any]) -> Void)?

    // MARK: - WatchConnectivity

    private let session: WCSession?

    // MARK: - Initialization

    override init() {
        if WCSession.isSupported() {
            session = WCSession.default
        } else {
            session = nil
        }

        super.init()
    }

    // MARK: - Activation

    /// WatchConnectivity 세션을 활성화합니다.
    func activate() {
        guard let session else {
            return
        }

        session.delegate = self
        session.activate()
    }

    // MARK: - Immediate Message

    /// iPhone 앱이 실행 중이고 연결 가능한 경우 즉시 메시지를 전송합니다.
    func sendMessage(_ message: [String: Any]) {
        guard let session else {
            return
        }

        guard session.activationState == .activated else {
            lastError = WorkoutConnectivityError.sessionNotActivated
            return
        }

        guard session.isReachable else {
            lastError = WorkoutConnectivityError.counterpartNotReachable
            return
        }

        session.sendMessage(
            message,
            replyHandler: nil
        ) { [weak self] error in
            Task { @MainActor in
                self?.lastError = error
            }
        }
    }

    // MARK: - Background Transfer

    /// iPhone이 즉시 응답할 수 없어도 전달할 최신 상태를 저장합니다.
    ///
    /// 같은 키의 데이터는 최신 값으로 교체됩니다.
    func updateApplicationContext(_ context: [String: Any]) {
        guard let session else {
            return
        }

        guard session.activationState == .activated else {
            lastError = WorkoutConnectivityError.sessionNotActivated
            return
        }

        do {
            try session.updateApplicationContext(context)
        } catch {
            lastError = error
        }
    }

    // MARK: - Error

    func clearError() {
        lastError = nil
    }
}

// MARK: - WCSessionDelegate

extension WorkoutConnectivity: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.isActivated = activationState == .activated
            self.isReachable = session.isReachable
            self.lastError = error
        }
    }

    nonisolated func sessionReachabilityDidChange(
        _ session: WCSession
    ) {
        Task { @MainActor [weak self] in
            self?.isReachable = session.isReachable
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor [weak self] in
            self?.onMessageReceived?(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor [weak self] in
            self?.onMessageReceived?(applicationContext)
        }
    }
}

// MARK: - Errors

enum WorkoutConnectivityError: LocalizedError {

    case sessionNotActivated
    case counterpartNotReachable

    var errorDescription: String? {
        switch self {
        case .sessionNotActivated:
            return "iPhone 연결 세션이 아직 활성화되지 않았습니다."

        case .counterpartNotReachable:
            return "현재 iPhone 앱에 즉시 연결할 수 없습니다."
        }
    }
}
