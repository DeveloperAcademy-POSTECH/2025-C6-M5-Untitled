import SwiftUI

struct BoardingLocation: View {
    var route: BusRouteNode
    var isActive: Bool = true
    @ObservedObject var viewModel = BusRouteViewModel()
    @State private var nearestBusInfo: (busNo: String, arrivalText: String)?
    @State private var didFetchOnce = false

    var body: some View {
        VStack(alignment: .leading, spacing: 15.wScaled) {
            
            // MARK: 정류장 정보
            VStack(alignment: .leading, spacing: 4.wScaled) {
                Text("정류장")
                    .font(.premed16Scaled)
                    .foregroundColor(Color.greyNormal)
                
                MarqueeText(
                    text: route.start.name,
                    font: .presemi24Scaled,
                    uiFont: .presemi24Scaled,
                    startDelay: 1.0,
                    alignment: .leading,
                    shouldAnimate: isActive
                )
                .foregroundColor(Color.primaryHeavy)
            }
            
            // MARK: 버스 도착 정보
            VStack(alignment: .leading, spacing: 4.wScaled) {
                Text("버스")
                    .font(.premed16Scaled)
                    .foregroundColor(Color.greyNormal)
                
                HStack(spacing: 8.wScaled) {
                    if let info = nearestBusInfo {
                        Text(info.busNo)
                            .font(.presemi24Scaled)
                            .foregroundColor(.primaryHeavy)
                        Text(info.arrivalText)
                            .font(.prereg16Scaled)
                            .foregroundColor(Color.greyNormal)
                    } else {
                        if !didFetchOnce {
                            Text("도착 정보 불러오는 중...")
                                .font(.presemi24Scaled)
                                .foregroundColor(Color.greyNormal)
                        } else {
                            Text(route.busNo[0])
                                .font(.presemi24Scaled)
                                .foregroundColor(.greyHeavy)
                            Text("도착 예정 정보 없음")
                                .font(.prereg16Scaled)
                                .foregroundColor(Color.greyNormal)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if !didFetchOnce {
                Task {
                    nearestBusInfo = await viewModel.fetchNearestBusInfo(for: route)
                    didFetchOnce = true
                }
            }
        }
    }
}
