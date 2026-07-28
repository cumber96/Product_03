import Foundation
import WatchConnectivity
import Combine

@MainActor
final class ConnectivityManager: NSObject, ObservableObject {
    static let shared = ConnectivityManager()

    @Published private(set) var connectionStatus = "연결 준비 중"
    @Published private(set) var receivedMessage = "받은 메시지 없음"

    @Published private(set) var latestWorkoutDuration: TimeInterval = 0
    @Published private(set) var latestWorkoutDistance: Double = 0
    @Published private(set) var latestWorkoutCalories: Double = 0
    @Published private(set) var latestWorkoutHeartRate: Double = 0
    @Published private(set) var latestWorkoutDate: Date?

    private override init() {
        super.init()
        activateSession()
    }

    // MARK: - 세션 활성화

    private func activateSession() {
        guard WCSession.isSupported() else {
            connectionStatus =
                "WatchConnectivity를 지원하지 않는 기기입니다."
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()

        connectionStatus = "연결 활성화 중"
    }

    // MARK: - 즉시 테스트 메시지

    func sendTestMessage() {
        let session = WCSession.default

        guard session.activationState == .activated else {
            connectionStatus =
                "연결이 아직 활성화되지 않았습니다."
            return
        }

        guard session.isReachable else {
            connectionStatus =
                "상대 앱에 지금 연결할 수 없습니다."
            return
        }

        session.sendMessage(
            [
                "type": "connectionTest",
                "message": "WatchConnectivity 연결 성공"
            ],
            replyHandler: { [weak self] reply in
                Task { @MainActor in
                    guard let self else {
                        return
                    }

                    self.connectionStatus =
                        reply["message"] as? String
                        ?? "응답을 받았습니다."
                }
            },
            errorHandler: { [weak self] error in
                Task { @MainActor in
                    guard let self else {
                        return
                    }

                    self.connectionStatus =
                        "메시지 전송 실패: \(error.localizedDescription)"
                }
            }
        )
    }

    // MARK: - 운동 결과 전송

    func transferWorkout(
        duration: TimeInterval,
        distance: Double,
        calories: Double,
        averageHeartRate: Double
    ) {
        let session = WCSession.default

        guard session.activationState == .activated else {
            connectionStatus =
                "운동 결과 전송 실패: 연결이 활성화되지 않았습니다."
            return
        }

        let workoutData: [String: Any] = [
            "type": "workoutSummary",
            "duration": duration,
            "distance": distance,
            "calories": calories,
            "averageHeartRate": averageHeartRate,
            "workoutDate": Date().timeIntervalSince1970
        ]

        session.transferUserInfo(workoutData)

        connectionStatus = "운동 결과 전송 대기 중"
    }

    // MARK: - 수신 데이터 처리

    private func processReceivedData(
        _ data: [String: Any]
    ) {
        guard let type = data["type"] as? String else {
            receivedMessage = "알 수 없는 데이터를 받았습니다."
            return
        }

        switch type {
        case "connectionTest":
            receivedMessage =
                data["message"] as? String
                ?? "테스트 메시지를 받았습니다."

        case "workoutSummary":
            latestWorkoutDuration =
                data["duration"] as? TimeInterval ?? 0

            latestWorkoutDistance =
                data["distance"] as? Double ?? 0

            latestWorkoutCalories =
                data["calories"] as? Double ?? 0

            latestWorkoutHeartRate =
                data["averageHeartRate"] as? Double ?? 0

            if let timestamp =
                data["workoutDate"] as? TimeInterval {

                latestWorkoutDate =
                    Date(timeIntervalSince1970: timestamp)
            }

            receivedMessage = "운동 기록을 받았습니다."
            connectionStatus = "운동 기록 수신 완료"

        default:
            receivedMessage = "지원하지 않는 데이터입니다."
        }
    }
}

// MARK: - WCSessionDelegate

extension ConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState:
            WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                connectionStatus =
                    "연결 활성화 실패: \(error.localizedDescription)"
                return
            }

            switch activationState {
            case .activated:
                connectionStatus = "연결 활성화 완료"

            case .inactive:
                connectionStatus = "연결 비활성 상태"

            case .notActivated:
                connectionStatus = "연결되지 않음"

            @unknown default:
                connectionStatus = "알 수 없는 연결 상태"
            }
        }
    }

    // 즉시 메시지 수신
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            processReceivedData(message)
        }

        replyHandler([
            "message": "상대 기기에서 메시지를 받았습니다."
        ])
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            processReceivedData(message)
        }
    }

    // 백그라운드 운동 결과 수신
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        Task { @MainActor in
            processReceivedData(userInfo)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(
        _ session: WCSession
    ) {
    }

    nonisolated func sessionDidDeactivate(
        _ session: WCSession
    ) {
        session.activate()
    }
    #endif
}
