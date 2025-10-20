import MapKit
import SwiftUI

private let kHasShownVoiceHint = "hasShownVoiceHint_v1"

struct MainSearchView: View {
    @AppStorage(kHasShownVoiceHint) private var hasShownVoiceHint = false
    
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @StateObject private var vm = MainSearchViewModel()

    @State private var hasSubmitted = false
    @State private var isSearchMode = false
    @State private var showHint = false
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
                        showHint = false
                        isFocused = false
                        coordinator.push(.voiceSearch)
                    },
                    onSelect: { item in
                        if let latitude = item.latitude, let longitude = item.longitude {
                            vm.setDestination(destination: LocationInfo(name: item.plainTitle, latitude: latitude, longitude: longitude))
                        }
                        // 초기화
                        vm.resetManager()
                        isSearchMode = false
                        coordinator.push(.routeSuggestion)
                    }
                )
            } else {
                IntroSection(
                    query: Binding(get: { vm.query }, set: { vm.query = $0 }),
                    isFocused: $isFocused,
                    showHint: $showHint,
                    onSubmit: { performSearch() },
                    onMicTap: {
                        showHint = false
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
        .onAppear {   // GPS 하드웨어 웜업용
            print("[DEBUG] requestOrigin")
            vm.requestOrigin()
        }
        .onChange(of: isFocused) { _, new in
            if new && !isSearchMode {
                isSearchMode = true
                DispatchQueue.main.async { isFocused = true }
            }
        }
        // SearchManager가 올린 전환 신호 감시
        .onChange(of: vm.shouldShowSearchMode) { _, show in
            if show {
                isSearchMode = true
                hasSubmitted = true
                vm.resetSearchMode()
            }
        }
        .onChange(of: isSearchMode) { _, _ in
            showHint = false
        }
        .onAppear {
            guard !hasShownVoiceHint else { return }  // 이미 본 적 있으면 패스
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                showHint = true
                hasShownVoiceHint = true
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
        showHint = false
        isSearchMode = true
        hasSubmitted = true
        Task { await vm.search() }
    }

    @MainActor func clearSearch() {
        showHint = false
        vm.query = ""
        hasSubmitted = false
        isFocused = true
    }
}
//#Preview {
//    MainSearchView()
//        .environmentObject(NavigationCoordinator())
//}
