import SwiftUI

struct MainSearchView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @ObservedObject private var vm = MainSearchViewModel.shared
    
    @State private var hasSubmitted = false
    @State private var isSearchMode = false
    @State private var suppressKeyboardOnce = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Group {
            if isSearchMode {
                SearchModeSection(
                    query: $vm.query,
                    results: vm.results,
                    isFocused: $isFocused,
                    onBack: { exitSearchMode() },
                    onSubmit: { performSearch() },
                    onClear: { clearSearch() },
                    onMicTap: {
                        isFocused = false
                        coordinator.push(.voiceSearch)}
                )
            } else {
                IntroSection(
                    query: $vm.query,
                    isFocused: $isFocused,
                    onSubmit: { performSearch() },
                    onMicTap: {
                        isFocused = false
                        coordinator.push(.voiceSearch) },
                    onClear: { clearSearch() }
                )
            }
        }
        .onTapGesture { isFocused = false }
        .animation(nil, value: vm.query)
        .toolbar(.hidden, for: .navigationBar)
        .background(Color(.systemBackground).ignoresSafeArea())
        .onChange(of: isFocused) { _, new in
            if new && !isSearchMode {
                isSearchMode = true
                DispatchQueue.main.async { isFocused = true }
            }
        }
        .onChange(of: vm.shouldShowSearchMode) { _, show in
            if show {
                isSearchMode = true
                hasSubmitted = true
                vm.resetSearchMode()
            }
        }
    }
}

// MARK: - Helpers
private extension MainSearchView {
    @MainActor func exitSearchMode() {
        isSearchMode = false
        isFocused = false
        hasSubmitted = false
        vm.query = ""
        vm.results = []
    }
    
    @MainActor func performSearch() {
        isSearchMode = true
        hasSubmitted = true
        Task { await vm.search() } // vm이 내부에서 메인 업데이트하도록 설계 권장
    }
    
    @MainActor func clearSearch() {
        vm.query = ""
        vm.results = []
        hasSubmitted = false
        isFocused = true
    }
}

//#Preview {
//    MainSearchView()
//        .environmentObject(NavigationCoordinator())
//}
