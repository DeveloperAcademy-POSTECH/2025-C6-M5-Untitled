import MapKit
import SwiftUI

struct MainSearchView: View {
    
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @StateObject private var viewModel = MainSearchViewModel()
    @FocusState private var isFocused: Bool
    
    var isDestination: Bool = true
    
    var body: some View {
        Group {
            if viewModel.isSearchMode {
                SearchModeSection(
                    query: Binding(
                        get: { viewModel.query },
                        set: { viewModel.query = $0 }
                    ),
                    results: viewModel.results,
                    isFocused: $isFocused,
                    onBack: {
                        viewModel.exitSearchMode()
                        isFocused = false
                    },
                    onSubmit: {
                        isFocused = false
                        Task { await viewModel.performSearch() }
                    },
                    onClear: {
                        viewModel.clearQuery()
                        isFocused = true
                    },
                    onMicTap: {
                        viewModel.handleMicTap()
                        isFocused = false
                    },
                    onSelect: { item in
                        viewModel.selectPlace(item: item)
                        coordinator.push(.routeSuggestion)
                    },
                    hasSubmitted: $viewModel.hasSubmitted,
                    isPresented: $viewModel.showDestinationMap,
                    isDestination: .constant(isDestination),
                    isLoading: viewModel.isLoading
                )
            } else {
                IntroSection(
                    query: Binding(get: { viewModel.query }, set: { viewModel.query = $0 }),
                    isFocused: $isFocused,
                    showHint: $viewModel.showHint,
                    onSubmit: {
                        isFocused = false
                        Task { await viewModel.performSearch() }
                    },
                    onMicTap: {
                        viewModel.handleMicTap()
                        isFocused = false
                    },
                    onClear: {
                        viewModel.clearQuery()
                        isFocused = true
                    }
                )
            }
        }
        .onTapGesture { isFocused = false }
        .animation(nil, value: viewModel.query)
        .toolbar(.hidden, for: .navigationBar)
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear {
            Task {
                try? await LocationService.shared.startLightTracking()
            }
            
            // GPS 하드웨어 웜업용
            viewModel.warmUpLocation()
            ProgressLiveActivityManager.shared.endActivity()
        }
        .onChange(of: isFocused) { _, new in
            if new && !viewModel.isSearchMode {
                viewModel.isSearchMode = true
                DispatchQueue.main.async { isFocused = true }
            }
        }
        .onChange(of: viewModel.shouldShowSearchMode) { _, show in
            if show {
                viewModel.isSearchMode = true
                viewModel.resetSearchMode()
            }
        }
        .onChange(of: viewModel.isSearchMode) { _, _ in
            viewModel.showHint = false
        }
        .onAppear {
            guard !viewModel.hasShownVoiceHint else { return }  // 이미 본 적 있으면 패스
            viewModel.showHint = true
            viewModel.hasShownVoiceHint = true
        }
    }
}
