//
//  ContentView.swift
//  RunContent Watch App Watch App
//
//  Created by 이홍원 on 7/28/26.
//ㅌ₩
import SwiftUI
import HealthKit

struct ContentView: View {
    private let healthStore = HKHealthStore()

    @State private var authorizationMessage = "권한 요청 전"

    var body: some View {
        VStack(spacing: 12) {
            Text("RunContent")
                .font(.headline)

            Text(authorizationMessage)
                .font(.caption)
                .multilineTextAlignment(.center)

            Button("건강 데이터 권한 요청") {
                requestHealthAuthorization()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func requestHealthAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationMessage = "이 기기에서는 HealthKit을 사용할 수 없습니다."
            return
        }

        guard
            let heartRate = HKObjectType.quantityType(
                forIdentifier: .heartRate
            ),
            let activeEnergy = HKObjectType.quantityType(
                forIdentifier: .activeEnergyBurned
            ),
            let distance = HKObjectType.quantityType(
                forIdentifier: .distanceWalkingRunning
            )
        else {
            authorizationMessage = "건강 데이터 유형을 불러오지 못했습니다."
            return
        }

        let workoutType = HKObjectType.workoutType()

        let typesToRead: Set<HKObjectType> = [
            heartRate,
            activeEnergy,
            distance,
            workoutType
        ]

        let typesToShare: Set<HKSampleType> = [
            workoutType,
            activeEnergy,
            distance
        ]

        healthStore.requestAuthorization(
            toShare: typesToShare,
            read: typesToRead
        ) { success, error in
            DispatchQueue.main.async {
                if let error {
                    authorizationMessage = "권한 요청 실패: \(error.localizedDescription)"
                    return
                }

                authorizationMessage = success
                    ? "권한 요청을 완료했습니다."
                    : "권한 요청을 완료하지 못했습니다."
            }
        }
    }
}

#Preview {
    ContentView()
}
