import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "검색어를 입력하세요"
    @FocusState.Binding var isFocused: Bool

    var compact: Bool = false
    var onSubmit: (() -> Void)?
    var onMicTap: (() -> Void)?
    var onClearTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            searchIcon
            textField
            actionButton
        }
        .padding(.horizontal, compact ? 12 : 14)
        .padding(.vertical, compact ? 10 : 12)
        .background(searchBarBackground)
    }
}

// MARK: - Components
private extension SearchBar {
    var searchIcon: some View {
        Image(systemName: "magnifyingglass")
            .foregroundStyle(.secondary)
    }

    var textField: some View {
        TextField(placeholder, text: $text)
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
                .font(.title3)
                .foregroundStyle(.black)
                .padding(6)
                .animation(nil, value: text.isEmpty)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    var searchBarBackground: some View {
        RoundedRectangle(cornerRadius: compact ? 14 : 16)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}
