import SwiftUI

struct MainSearchView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @StateObject private var vm = MainSearchViewModel()

    @State private var hasSubmitted = false
    @State private var isSearchMode = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isSearchMode {
                SearchModeSection(
                    query: Binding(get: { vm.query }, set: { vm.query = $0 }),
                    results: vm.results,
                    isFocused: $isFocused,
                    onBack: { exitSearchMode() },
                    onSubmit: { performSearch() },
                    onClear: { clearSearch() },
                    onMicTap: {
                        isFocused = false
                        coordinator.push(.voiceSearch)
                    }
                )
            } else {
                IntroSection(
                    query: Binding(get: { vm.query }, set: { vm.query = $0 }),
                    isFocused: $isFocused,
                    onSubmit: { performSearch() },
                    onMicTap: {
                        isFocused = false
                        coordinator.push(.voiceSearch)
                    },
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
        // ✅ SearchManager가 올린 전환 신호 감시
        .onChange(of: vm.shouldShowSearchMode) { _, show in
            if show {
                isSearchMode = true
                hasSubmitted = true
                vm.resetSearchMode()
            }
        }
    }

    // MARK: - Helpers
    @MainActor func exitSearchMode() {
        isSearchMode = false
        isFocused = false
        hasSubmitted = false
        vm.query = ""
        // vm.results는 매니저가 관리하니 굳이 초기화 필요 없음
    }

    @MainActor func performSearch() {
        isSearchMode = true
        hasSubmitted = true
        Task { await vm.search() }
    }

    @MainActor func clearSearch() {
        vm.query = ""
        hasSubmitted = false
        isFocused = true
    }
}
//#Preview {
//    MainSearchView()
//        .environmentObject(NavigationCoordinator())
//}
