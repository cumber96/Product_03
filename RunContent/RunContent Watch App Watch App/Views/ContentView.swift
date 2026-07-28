//
//  ContentView.swift
//  RunContent Watch App
//

import SwiftUI

@MainActor
struct ContentView: View {

    @StateObject private var workoutManager: WorkoutManager

    init() {
        _workoutManager = StateObject(
            wrappedValue: WorkoutManager()
        )
    }

    var body: some View {
        WorkoutDashboardView(
            manager: workoutManager,
            store: workoutManager.store
        )
    }
}

@MainActor
private struct WorkoutDashboardView: View {

    let manager: WorkoutManager

    @ObservedObject var store: WorkoutStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                statusView

                metricView(
                    title: "시간",
                    value: formattedElapsedTime
                )

                metricView(
                    title: "심박수",
                    value: "\(Int(store.heartRate)) BPM"
                )

                metricView(
                    title: "거리",
                    value: String(
                        format: "%.2f km",
                        store.distance / 1_000
                    )
                )

                metricView(
                    title: "평균 페이스",
                    value: formattedAveragePace
                )

                metricView(
                    title: "활동 에너지",
                    value: "\(Int(store.activeEnergy)) kcal"
                )

                workoutControls

                if let error = store.lastError {
                    Text(error.localizedDescription)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
    }

    // MARK: - Status

    private var statusView: some View {
        Text(statusMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private var statusMessage: String {
        switch store.state {
        case .idle:
            return "운동 준비"

        case .preparing:
            return "운동을 준비하고 있습니다"

        case .running:
            return "운동 중"

        case .paused:
            return "일시정지"

        case .ending:
            return "운동을 종료하고 있습니다"

        case .ended:
            return "운동 완료"
        }
    }

    // MARK: - Metrics

    private func metricView(
        title: String,
        value: String
    ) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedElapsedTime: String {
        let totalSeconds = Int(store.elapsedTime)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(
                format: "%d:%02d:%02d",
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

    private var formattedAveragePace: String {
        guard
            let pace = store.averagePace,
            pace.isFinite
        else {
            return "--'--\""
        }

        let totalSeconds = Int(pace)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return String(
            format: "%d'%02d\"",
            minutes,
            seconds
        )
    }

    // MARK: - Controls

    @ViewBuilder
    private var workoutControls: some View {
        switch store.state {
        case .idle, .ended:
            Button {
                if store.state == .ended {
                    manager.resetWorkout()
                }

                manager.startWorkout()
            } label: {
                Label(
                    "운동 시작",
                    systemImage: "figure.run"
                )
            }
            .buttonStyle(.borderedProminent)

        case .preparing:
            ProgressView()

        case .running:
            HStack {
                Button {
                    manager.pauseWorkout()
                } label: {
                    Image(systemName: "pause.fill")
                }
                .tint(.yellow)

                Button {
                    manager.endWorkout()
                } label: {
                    Image(systemName: "xmark")
                }
                .tint(.red)
            }

        case .paused:
            HStack {
                Button {
                    manager.resumeWorkout()
                } label: {
                    Image(systemName: "play.fill")
                }
                .tint(.green)

                Button {
                    manager.endWorkout()
                } label: {
                    Image(systemName: "xmark")
                }
                .tint(.red)
            }

        case .ending:
            ProgressView()
        }
    }
}

#Preview {
    ContentView()
}
