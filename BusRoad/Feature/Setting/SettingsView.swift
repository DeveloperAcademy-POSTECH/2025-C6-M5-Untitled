import SwiftUI


struct SettingsView: View {
    @AppStorage(SettingsKeys.busArrivalVoice) private var busArrivalVoiceEnabled: Bool = true
    @AppStorage(SettingsKeys.busAlightVoice)  private var busAlightVoiceEnabled: Bool = true
    @AppStorage(SettingsKeys.walkingVoice)    private var walkingVoiceEnabled: Bool = true
    @AppStorage(SettingsKeys.vibration)       private var vibrationEnabled: Bool = true

    var body: some View {
        ZStack {
            Color(.background)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing:0) {

                // 음성 알림 헤더
                HStack(spacing: 1) {
                    Text("음성 알림")
                        .font(.presemi18)
                    
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.secondary)
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
}

#Preview {
    SettingsView()
}
