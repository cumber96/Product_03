import SwiftUI

struct ContentView: View {

    @EnvironmentObject
    private var connectivityManager: ConnectivityManager

    var body: some View {

        NavigationStack {

            VStack(spacing: 24) {

                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)

                Text("RunContent")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 12) {

                    Text("연결 상태")
                        .font(.headline)

                    Text(connectivityManager.connectionStatus)
                        .foregroundStyle(.secondary)

                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                VStack(alignment: .leading, spacing: 12) {

                    Text("받은 메시지")
                        .font(.headline)

                    Text(connectivityManager.receivedMessage)
                        .foregroundStyle(.secondary)

                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                Button {

                    connectivityManager.sendTestMessage()

                } label: {

                    Label(
                        "Watch에 테스트 메시지 보내기",
                        systemImage: "paperplane.fill"
                    )
                    .frame(maxWidth: .infinity)

                }
                .buttonStyle(.borderedProminent)

            }
            .padding()

        }

    }
}

#Preview {
    ContentView()
        .environmentObject(
            ConnectivityManager.shared
        )
}
