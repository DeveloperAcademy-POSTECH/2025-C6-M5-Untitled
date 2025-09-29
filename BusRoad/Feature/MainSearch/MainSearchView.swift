import SwiftUI

struct MainSearchView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @EnvironmentObject var vm: MainSearchViewModel

    @State var hasSubmitted = false
    @State var isSearchMode = false
    @State private var suppressKeyboardOnce = false
    @FocusState var isFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            if !isSearchMode {
                introView
            } else {
                searchModeView
            }
        }
        .onTapGesture { isFocused = false }
        .animation(nil, value: vm.query)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .background(Color(.systemBackground).ignoresSafeArea())

        // 포커스 변경 → 검색모드 진입
        .onChange(of: isFocused) { _, new in
            if new && !isSearchMode {
                isSearchMode = true
                DispatchQueue.main.async { isFocused = true }
            }
        }

        // 음성검색에서 진입 시 검색모드로 전환
        .onChange(of: vm.shouldShowSearchMode) { _, show in
            if show {
                isSearchMode = true
                hasSubmitted = true
                if vm.isFromVoiceSearch { isFocused = false }
                vm.resetSearchMode()
            }
        }
    }
}

#Preview {
    MainSearchView()
        .environmentObject(NavigationCoordinator())
        .environmentObject(MainSearchViewModel())
}
