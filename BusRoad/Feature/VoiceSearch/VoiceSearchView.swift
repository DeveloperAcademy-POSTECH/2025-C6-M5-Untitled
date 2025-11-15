import SwiftUI

struct VoiceSearchView: View {
    
    let onCompleted: (String) -> Void
    let onDismiss: () -> Void
    
    @StateObject var viewModel = VoiceSearchViewModel()
    
    
    var body: some View {
        ZStack {
            Color.primaryNormal
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                Text(viewModel.centerMessage)
                    .font(.premed28)
                    .foregroundStyle(.subLight)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                ZStack {
                    if viewModel.showWaveAnimation {
                        WaveRingsView()
                    }
                    Button(action: viewModel.handleMicButtonTap) {
                        ZStack {
                            Circle()
                                .fill(.subNormal)
                                .frame(width: 105, height: 105)
                            Image("big-mic")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                        }
                    }
                }
                .frame(width: 200, height: 200) // 화면 움직이지 않도록 frame 값
                .padding(.bottom, 11.wScaled)
            }
            
            // 닫기 버튼
            VStack {
                HStack {
                    Spacer()
                    Button {
                        viewModel.dismiss()
                    } label: {
                        Image("xbutton-white")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .foregroundColor(.primarywhite)
                    }
                    .padding(.top, 13)
                    .padding(.trailing, 24)
                }
                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
           // 음성 인식 완료 시
            viewModel.onSearchCompleted = { text in
                onCompleted(text)
            }
            
          // 닫기
            viewModel.onDismiss = {
                onDismiss()
            }
            
            // 실제 리스닝 시작/바인딩
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }
}
