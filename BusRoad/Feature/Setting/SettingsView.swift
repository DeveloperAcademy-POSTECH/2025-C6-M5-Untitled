import SwiftUI


struct SettingsView: View {
    @AppStorage(SettingsKeys.busArrivalVoice) private var busArrivalVoiceEnabled: Bool = true
    @AppStorage(SettingsKeys.busAlightVoice)  private var busAlightVoiceEnabled: Bool = true
    @AppStorage(SettingsKeys.walkingVoice)    private var walkingVoiceEnabled: Bool = true
    @AppStorage(SettingsKeys.vibration)       private var vibrationEnabled: Bool = true
    
    @State private var showVoiceTooltip: Bool = false
    
    var body: some View {
        ZStack {
            Color(.background)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing:0) {
                
                // 음성 알림 헤더
                HStack(spacing: 1) {
                    Text("음성 알림")
                        .font(.presemi18)
                    
                    Button {
                        showVoiceTooltip.toggle()
                    } label: {
                        Image("info")
                    }
                }
                .padding(.vertical, 9)
                
                // 카드
                VStack(spacing: 0) {
                    settingRow(title: "버스 승차(도착) 알림", isOn: $busArrivalVoiceEnabled)
                    divider()
                    settingRow(title: "버스 하차 알림", isOn: $busAlightVoiceEnabled)
                    divider()
                    settingRow(title: "도보 안내 알림", isOn: $walkingVoiceEnabled)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.primarywhite))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                )
                //                .overlay(alignment: .topLeading) {
                //                    if showVoiceTooltip {
                //                        VoiceTooltipView { showVoiceTooltip = false }
                //                    }
                //
                //                }
                
                // 진동 알림
                HStack {
                    Text("진동 알림")
                        .font(.presemi18)
                    Spacer()
                    Toggle("", isOn: $vibrationEnabled)
                        .labelsHidden()
                        .tint(.primaryNormal)
                        .padding(.trailing, 16)
                }
                .padding(.top, 26)
                
                Spacer()
            }
            .padding(.horizontal, 23)
            
            
            if showVoiceTooltip {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showVoiceTooltip = false
                    }
                
                VoiceTooltipView {
                    showVoiceTooltip = false
                }
                .frame(height: 77)
                .position(x: UIScreen.main.bounds.width / 1.7,
                          y: 70)
            }
            
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    
    // MARK: - 컴포넌트들
    private func settingRow(
        title: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack {
            Text(title)
                .font(.premed16Scaled)
                .foregroundStyle(.greyStrong)
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.primaryNormal)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private func divider() -> some View {
        Divider().padding(.horizontal, 10)
    }
    
    /// 툴팁
    private struct VoiceTooltipView: View {
        let onClose: () -> Void
        
        var body: some View {
            VStack(spacing: 3) {
                HStack(alignment: .top) {
                    VStack {
                        Spacer()
                        
                        Text("아이폰 무음 모드가 켜져 있으면 음성 알림이\n들리지 않아요.")
                            .font(.premed14)
                            .foregroundStyle(.primaryblack)
                    }
                    
                    Button(action: onClose) {
                        Image("small-xbutton")
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                }
                
                Text("음성 알림을 들으려면 무음 모드를 해제해주세요.")
                    .font(.prereg14)
                    .foregroundStyle(.primaryblack)
            }
            .padding(.leading, 11)
            .padding(.bottom, 11)
            .padding(.top, 4)
            .padding(.trailing, 4)
            .background(
                Rectangle()
                    .fill(Color(.primarywhite))
            )
            .overlay(
                Rectangle()
                    .stroke(Color.primaryblack.opacity(0.06), lineWidth: 1)
            )
            
        }
    }
}


#Preview {
    SettingsView()
}
