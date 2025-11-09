import SwiftUI

struct WalkingRerouteAlert: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: WalkingViewModel

    let journey: Journey
    let index: Int

    var selection: Int = 50

    var body: some View {
        if isPresented {
            ZStack {
                Color.primaryblack
                    .opacity(0.5)
                    .ignoresSafeArea()

                VStack(alignment: .center, spacing: 0) {
                    // 타이틀
                    Text("경로에서 벗어난 것 같아요")
                        .font(.presemi24Scaled)
                        .foregroundColor(.primaryblack)
                        .padding(.top, 20.wScaled)

                    // 버튼 영역
                    HStack(spacing: 9.wScaled) {
                        // 닫기(= 나중에)
                        Button {
                            viewModel.deferRealert(seconds: 45) // 재등장 쿨다운
                            isPresented = false
                        } label: {
                            ZStack {
                                Rectangle()
                                    .cornerRadius(100)
                                    .foregroundColor(Color.greybutton)
                                    .frame(width: 139.wScaled, height: 48.wScaled)
                                Text("나중에")
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
                                Text("재탐색")
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
