import SwiftUI

struct SearchModeSection: View {
    @Binding var query: String
    let results: [NaverLocalItem]          // vm.results의 요소 타입에 맞춰서
    var isFocused: FocusState<Bool>.Binding

    let onBack: () -> Void
    let onSubmit: () -> Void
    let onClear: () -> Void
    let onMicTap: () -> Void
    let onSelect: (NaverLocalItem) -> Void
    
    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                header
                list
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.plain)

            SearchBar(
                text: $query,
                isFocused: isFocused,
                onSubmit: onSubmit,
                onMicTap: onMicTap,          // 검색 모드 헤더엔 마이크 없으면 비워둠
                onClearTap: onClear
            )
        }
        .padding(.horizontal, 16)
    }

    private var list: some View {
        VStack {
            if results.isEmpty && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("") // 필요 시 플레이스홀더
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(results) { item in
                        PlaceCard(
                            title: item.plainTitle,
                            address: item.displayAddress,
                            searchQuery: query.trimmingCharacters(in: .whitespacesAndNewlines)
                        ) {
                            // onTap
                            onSelect(item)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}
