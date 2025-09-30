import SwiftUI

struct IntroSection: View {
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding

    let onSubmit: () -> Void
    let onMicTap: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("어디로 갈까요?")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(Color.green.opacity(0.9))

            SearchBar(
                text: $query,
                placeholder: "장소 이름 검색하기",
                isFocused: isFocused,
                compact: false,
                onSubmit: onSubmit,
                onMicTap: onMicTap,
                onClearTap: onClear
            )
            .padding(.horizontal, 16)

            Spacer()
        }
    }
}
