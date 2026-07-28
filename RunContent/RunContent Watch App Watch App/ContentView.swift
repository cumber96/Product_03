import SwiftUI

struct ContentView: View {
    @StateObject private var workoutManager =
        WorkoutManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(workoutManager.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                metricView(
                    title: "시간",
                    value: workoutManager.formattedElapsedTime
                )

                metricView(
                    title: "심박수",
                    value: "\(Int(workoutManager.heartRate)) BPM"
                )

                metricView(
                    title: "거리",
                    value: String(
                        format: "%.2f km",
                        workoutManager.distance / 1000
                    )
                )

                metricView(
                    title: "평균 페이스",
                    value: workoutManager.formattedAveragePace
                )

                metricView(
                    title: "활동 칼로리",
                    value: String(
                        format: "%.0f kcal",
                        workoutManager.activeEnergy
                    )
                )

                workoutControls
            }
            .padding()
        }
    }

    @ViewBuilder
    private var workoutControls: some View {
        if workoutManager.isWorkoutEnding {
            ProgressView()
                .padding(.top, 4)

            Text("운동을 저장하고 있어요")
                .font(.caption2)
                .foregroundStyle(.secondary)

        } else if workoutManager.isWorkoutRunning {
            if workoutManager.isWorkoutPaused {
                Button {
                    workoutManager.resumeWorkout()
                } label: {
                    Label(
                        "운동 재개",
                        systemImage: "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)

            } else {
                Button {
                    workoutManager.pauseWorkout()
                } label: {
                    Label(
                        "일시정지",
                        systemImage: "pause.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
            }

            Button(
                role: .destructive
            ) {
                workoutManager.stopWorkout()
            } label: {
                Label(
                    "운동 종료",
                    systemImage: "stop.fill"
                )
            }

        } else {
            Button {
                workoutManager.startWorkout()
            } label: {
                Label(
                    "운동 시작",
                    systemImage: "figure.run"
                )
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func metricView(
        title: String,
        value: String
    ) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }
}

#Preview {
    ContentView()
}
