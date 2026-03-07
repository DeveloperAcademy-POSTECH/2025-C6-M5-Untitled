import SwiftUI
import Lottie


struct BeforeRideCard: View {
    @ObservedObject var viewModel: BeforeRideViewModel
    var waitingStopName: String
    var englishWaitingStopName: String
    var waitingBusNo: [String]
    
    let languageCode = Locale.current.language.languageCode?.identifier
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(viewModel.isArrivingSoon ? .primaryStrong : .primarywhite)
                .cornerRadius(20)
                .shadow(
                    color: viewModel.isArrivingSoon ? .clear : .black.opacity(0.25),
                    radius: viewModel.isArrivingSoon ? 0 : 2,
                    x: 0,
                    y: 0
                )
            
            if viewModel.isReady {
                // 데이터 로드 완료 - 내용 표시
                cardContent
            } else {
                // 로딩 중 - 빈 카드
                ProgressView()
                    .tint(.greyDisable)
                    .scaleEffect(3)
            }
        }
    }
    
    private var cardContent: some View {
        VStack(spacing: 32.wScaled) {
            VStack(spacing: 28.wScaled) {
                HStack {
                    VStack(alignment: .leading, spacing: 8.wScaled) {
                        
                        Text("승차정류장")
                            .font(.prereg24Scaled)
                            .foregroundStyle(viewModel.isArrivingSoon ? .subLight : .primaryHeavy)
                        
                        MarqueeText(
                            text: languageCode == "ko" ? waitingStopName : englishWaitingStopName,
                            font: .presemi36Scaled,
                            uiFont: .presemi36Scaled,
                            startDelay: 1.0,
                            alignment: .leading
                        )
                        .foregroundStyle(viewModel.isArrivingSoon ? .subLight : .primaryHeavy)
                        
                    }
                    Spacer()
                }
                
                if let info = viewModel.nearestBusInfo {
                    HStack {
                        Text(info.busNo)
                            .font(.presemi32Scaled)
                            .foregroundStyle(viewModel.isArrivingSoon ? .primaryHeavy : .subLight)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 8.wScaled)
                            .padding(.vertical, 4.wScaled)
                            .background(
                                Rectangle()
                                    .foregroundStyle(viewModel.isArrivingSoon ? .subNormal : .primaryHeavy)
                                    .cornerRadius(15)
                            )
                        
                        Spacer()
                            .frame(width: 8.wScaled)
                        
                        Text(info.arrivalText)
                            .font(.premed20Scaled)
                            .foregroundStyle(viewModel.isArrivingSoon ? .subLight : .primaryHeavy)
                        
                        Spacer()
                    }
                } else {
                    // 도착 정보 없음
                    HStack {
                        Text(waitingBusNo[0])
                            .font(.presemi32Scaled)
                            .foregroundStyle(.subLight)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 8.wScaled)
                            .padding(.vertical, 4.wScaled)
                            .background(
                                Rectangle()
                                    .foregroundColor(.primaryHeavy)
                                    .cornerRadius(15)
                            )
                        
                        Spacer()
                            .frame(width: 8.wScaled)
                        
                        Text("도착 정보 없음")
                            .font(.premed20Scaled)
                            .foregroundStyle(viewModel.isArrivingSoon ? .subLight : .primaryHeavy)
                        
                        Spacer()
                    }
                }
            }
            
            LottieView(animation: .named(viewModel.isArrivingSoon ? "BeforeBoarding" : "BeforeRiding"))
                .playing(loopMode: .loop)
                .animationSpeed(1.0)
                .frame(width: 200.wScaled, height: 200.wScaled)
                .padding(.leading, viewModel.isArrivingSoon ? 25.wScaled : 0)
                .padding(.top, viewModel.isArrivingSoon ? 20.wScaled : 0)
        }
        .padding(.horizontal, 40.wScaled)
    }
}
