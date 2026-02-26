import SwiftUI

struct IntroSection: View {
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding
    
    @Binding var showHint: Bool
    
    let onSubmit: () -> Void
    let onMicTap: () -> Void
    let onClear: () -> Void
    let onSettingsTap: () -> Void
    
    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    
                    Button {
                        onSettingsTap()
                    } label: {
                        Image("setting")
                            .foregroundStyle(.greyStrong)
                            .frame(width: 30.wScaled, height: 30.wScaled)
                    }
                }
                .padding(.top, 55)
                .padding(.horizontal, 16)
                
                Spacer()
                
                VStack(spacing: 45) {
                    
                    Text("어디로 갈까요?")
                        .font(.papersemi36)
                        .foregroundStyle(.primaryNormal)
                    
                    SearchBar(
                        text: $query,
                        isFocused: isFocused,
                        onSubmit: onSubmit,
                        onMicTap: onMicTap,
                        onClearTap: onClear
                    )
                    .padding(.horizontal, 22)
                    .overlay(alignment: .topTrailing) {
                        if showHint {
                            ZStack{
                                Image("voicetip")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 148, height: 47)
                                    .offset(x: -10, y: 67)
                                Text("음성으로 찾기")
                                    .font(.premed14)
                                    .foregroundStyle(.primaryHeavy)
                                    .offset(x: -10, y: 71)
                            }
                        }
                    }
                }
                .padding(.top, 174)
                .padding(.bottom, 445)
            }
        }
    }
}

#Preview {
    @Previewable @State var showHint = true
    @Previewable @State var text = ""
    @FocusState var isFocused: Bool
    
    return IntroSection(
        query: $text,
        isFocused: $isFocused,
        showHint: $showHint,
        onSubmit: {},
        onMicTap: {},
        onClear: {},
        onSettingsTap: {}
    )
}
