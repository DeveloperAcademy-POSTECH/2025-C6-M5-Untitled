import SwiftUI

struct WalkingRerouteAlert: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @Binding var isPresented: Bool
    @ObservedObject var viewModel = WalkingViewModel()
    var selection: Int = 50

    var body: some View {
        if isPresented {
            ZStack {
                Color.primaryblack
                    .opacity(0.5)
                    .ignoresSafeArea()

                VStack(alignment: .center) {
                    // 타이틀
                    Text("경로에서 벗어났어요")
                        .font(.presemi24Scaled)
                        .foregroundColor(.primaryblack)
                        .padding(.top, 20.wScaled)
                        .padding(.bottom, 10.wScaled)
                    
                    // 상세 설명
                    Text("현재 위치에서 다시\n경로를 검색할까요?")
                      .font(.prereg20Scaled)
                      .foregroundColor(.primaryblack)
                     .multilineTextAlignment(.center)
                     .padding(.bottom, 36.wScaled)

                    // 버튼 영역
                    HStack(spacing: 9.wScaled) {
                        // 닫기
                        Button {
                            viewModel.deferRealert(seconds: 45) // 재등장 쿨다운
                            isPresented = false
                        } label: {
                            ZStack {
                                Rectangle()
                                    .cornerRadius(100)
                                    .foregroundColor(Color.greybutton)
                                    .frame(width: 139.wScaled, height: 48.wScaled)
                                Text("취소")
                                    .foregroundColor(Color.primaryblack)
                                    .font(.premed20Scaled)
                            }
                        }

                        // 재탐색
                        Button {
                            viewModel.setOffRouteThreshold(selection)
                            viewModel.offRouteViolations = 0
                            viewModel.rerouteIfNeeded()
                            isPresented = false
                        } label: {
                            ZStack {
                                Rectangle()
                                    .cornerRadius(100)
                                    .foregroundColor(Color.subPoint)
                                    .frame(width: 139.wScaled, height: 48.wScaled)
                                Text("다시 검색")
                                    .foregroundColor(Color.primarywhite)
                                    .font(.premed20Scaled)
                            }
                        }
                    }
                    .padding(.top, 24.wScaled)
                    .padding(.bottom, 20.wScaled)
                }
                .frame(width: 320.wScaled)
                .background(
                    RoundedRectangle(cornerRadius: 35)
                        .fill(Color.alertbackground) // 내부 색상
                        .overlay(
                            RoundedRectangle(cornerRadius: 35)
                                .stroke(Color.primarywhite, lineWidth: 0.5)
                        )
                )
            }
            .background(.clear)
        }
    }
}
