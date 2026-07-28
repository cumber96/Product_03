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

                if workoutManager.isWorkoutRunning {
                    Button(
                        "운동 종료",
                        role: .destructive
                    ) {
                        workoutManager.stopWorkout()
                    }
                } else {
                    Button("운동 시작") {
                        workoutManager.startWorkout()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
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
