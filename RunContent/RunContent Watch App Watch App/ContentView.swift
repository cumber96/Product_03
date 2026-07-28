import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()

    var body: some View {
        VStack(spacing: 14) {
            Text("RunContent")
                .font(.headline)

            Text(workoutManager.statusMessage)
                .font(.caption)
                .multilineTextAlignment(.center)

            if workoutManager.isWorkoutRunning {
                Button("운동 종료", role: .destructive) {
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

#Preview {
    ContentView()
}
