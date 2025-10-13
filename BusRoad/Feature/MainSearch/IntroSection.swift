import SwiftUI

struct IntroSection: View {
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding
    
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
            }
            .padding(.top, 265)
            .padding(.bottom, 445)
            
            
        }
    }
}
