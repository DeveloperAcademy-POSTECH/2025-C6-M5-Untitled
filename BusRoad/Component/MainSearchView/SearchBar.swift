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
        .padding(.vertical, 8.5) // 내부 패딩 값
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
            if text.isEmpty { micButton } else { xButton }
        }
        .animation(nil, value: text.isEmpty)
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
    }
    
    var searchBarBackground: some View {
        RoundedRectangle(cornerRadius: 25)
            .fill(.primarywhite
            )
            .stroke(Color(.subStrong), lineWidth: 1.5)
    }
    
    var micButton: some View {
        Image("big-mic")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 18, height: 24)
    }
    
    var xButton: some View {
        Image("gray.xbutton")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 20, height: 20)
        
    }
    
}
