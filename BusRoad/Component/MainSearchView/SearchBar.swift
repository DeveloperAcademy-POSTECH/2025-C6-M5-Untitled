import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    
    var onSubmit: (() -> Void)?
    var onMicTap: (() -> Void)?
    var onClearTap: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 8) {
            searchIcon
            textField
            actionButton
        }
        .padding(.leading, 20) // 내부 패딩 값
        .padding(.trailing, 12) // 내부 패딩 값
        .padding(.vertical, 9) // 내부 패딩 값
        .background(searchBarBackground)
    }
}

// MARK: - Components
private extension SearchBar {
    var searchIcon: some View {
        Image(systemName: "magnifyingglass")
            .foregroundStyle(.greyDisable)
    }
    
    var textField: some View {
        TextField("검색",
                  text: $text,
                  prompt: Text("장소 이름 검색하기").foregroundStyle(.greyDisable)
        )
        .foregroundStyle(.greyHeavy)
        .font(.prereg20)
        .focused($isFocused)
        .textInputAutocapitalization(.never)
        .disableAutocorrection(true)
        .submitLabel(.search)
        .onSubmit { onSubmit?() }
    }
    
    var actionButton: some View {
        Button {
            if text.isEmpty { onMicTap?() } else { onClearTap?() }
        } label: {
            Image(systemName: text.isEmpty ? "mic.fill" : "xmark.circle.fill")
                .font(.title2) //TODO: 아이콘 폰트 크기 논의 필요
                .foregroundStyle(text.isEmpty ? .primaryNormal : .greyDisable )
                .padding(12)
                .animation(nil, value: text.isEmpty)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
    
    var searchBarBackground: some View {
        RoundedRectangle(cornerRadius: 25)
            .fill(.white)
            .stroke(Color(.subStrong), lineWidth: 1.5)
    }
}
