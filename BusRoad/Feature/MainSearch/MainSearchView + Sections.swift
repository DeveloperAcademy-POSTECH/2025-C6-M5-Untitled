import SwiftUI

extension MainSearchView {

    /// 초기 화면 - 중앙 큰 검색바
    var introView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("어디로 갈까요?")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(Color.green.opacity(0.9))
            searchBar(compact: false)
                .padding(.horizontal, 16)
            Spacer()
        }
    }

    /// 검색 모드 화면
    var searchModeView: some View {
        VStack(spacing: 12) {
            searchHeader
            searchResults
        }
    }

    /// 상단 헤더: 뒤로가기 + 컴팩트 검색바
    var searchHeader: some View {
        HStack(spacing: 12) {
            Button { exitSearchMode() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.plain)

            searchBar(compact: true)
        }
        .padding(.horizontal, 16)
    }

    /// 결과 리스트
    var searchResults: some View {
        VStack {
            // 빈 상태 처리 (조건 단순화)
            if vm.results.isEmpty && vm.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("") // 필요시 플레이스홀더 문구
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.results) { item in
                        PlaceCard(
                            title: item.plainTitle,
                            address: item.displayAddress,
                            searchQuery: vm.query.trimmingCharacters(in: .whitespacesAndNewlines)
                        ) {
                            // TODO: 탭 액션 (예: coordinator.push(.routeSuggestion(item)))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    /// 검색바 팩토리
    func searchBar(compact: Bool) -> some View {
        SearchBar(
            text: $vm.query,
            placeholder: "장소 이름 검색하기",
            isFocused: $isFocused,
            compact: compact,
            onSubmit: { performSearch() },
            onMicTap: { coordinator.push(.voiceSearch) },
            onClearTap: { clearSearch() }
        )
    }
}
