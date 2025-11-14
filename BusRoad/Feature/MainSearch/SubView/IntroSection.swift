import SwiftUI

struct IntroSection: View {
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding
    
    @Binding var showHint: Bool
    
    let onSubmit: () -> Void
    let onMicTap: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            
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
                        Image("voicetip")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 148, height: 47)
                            .offset(x: -10, y: 67)
                    }
                }
            }
            .padding(.top, 265)
            .padding(.bottom, 445)
            
            
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
        onClear: {}
    )
}
