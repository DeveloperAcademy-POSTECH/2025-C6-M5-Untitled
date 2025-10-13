import SwiftUI

struct OnRideView: View {
    @StateObject private var vm = OnRideViewModel()
    
    var body: some View {
        ZStack {
            Color(.background)
                .ignoresSafeArea()
            
            VStack(spacing: 47) {
                
                OnRideCard(
                    busStopName: vm.stopName,
                    remainingStops: vm.remainingStops,
                    progress: vm.progress
                )
                .padding(.horizontal, 24)
                
                
                if vm.remainingStops == 1 {
                    Button {
                       // TODO: 다음화면으로 넘어가도록하는 액션
                    } label: {
                        Text("내렸어요")
                            .font(.premed32)
                            .foregroundStyle(.subLight)
                            .frame(width: 239, height: 74)
                            .background(.subStrong)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        // TODO: 비활성화 상태에서의 동작(토스트/알럿/햅틱 등)
                        // “1정류장 남으면 버튼이 활성화돼요”
                    } label: {
                        Text("내렸어요")
                            .font(.premed32)
                            .foregroundStyle(.subNeutral)
                            .frame(width: 239, height: 74)
                            .background(.subDisable)
                            .cornerRadius(20)
                    }
                }
            }
        }
    }
}


#Preview {
    OnRideView()
}
