import SwiftUI

struct WalkingRerouteAlert: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: WalkingViewModel

    let journey: Journey
    let index: Int

    @State private var selection: Int = 50
    private let choices: [Int] = [30, 50, 100]

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

                    // 보조 설명
                    Text("일시적으로 길에서 벗어나면 안내가 부정확해질 수 있어요.\n어느 정도 벗어나면 재탐색할지 선택해 주세요.")
                        .multilineTextAlignment(.center)
                        .font(.premed14Scaled)
                        .foregroundColor(.primaryHeavy)
                        .padding(.top, 12.wScaled)
                        .padding(.horizontal, 20.wScaled)

                    // 거리 선택(30 / 50 / 100m)
                    HStack(spacing: 8.wScaled) {
                        ForEach(choices, id: \.self) { m in
                            Button {
                                selection = m
                            } label: {
                                ZStack {
                                    // 선택/비선택 배경
                                    RoundedRectangle(cornerRadius: 100)
                                        .fill(selection == m ? Color.subPoint.opacity(0.15) : Color.greybutton)
                                        .frame(height: 36.wScaled)
                                    // 테두리
                                    RoundedRectangle(cornerRadius: 100)
                                        .stroke(selection == m ? Color.subPoint : Color.primarywhite.opacity(0.5), lineWidth: selection == m ? 1.5 : 1)
                                        .frame(height: 36.wScaled)
                                    // 라벨
                                    Text("\(m)m")
                                        .font(.premed14Scaled)
                                        .foregroundColor(selection == m ? .subPoint : .primaryblack)
                                }
                            }
                            .frame(minWidth: 0, maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20.wScaled)
                    .padding(.top, 16.wScaled)

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
            .onAppear {
                // 기존 설정값과 동기화
                let v = Int(viewModel.offRouteThreshold)
                // 30/50/100 중 가장 가까운 값으로 스냅
                selection = choices.min(by: { abs($0 - v) < abs($1 - v) }) ?? 50
            }
        }
    }
}
