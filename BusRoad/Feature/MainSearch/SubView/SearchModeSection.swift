import SwiftUI

struct SearchModeSection: View {
    @Binding var query: String
    let results: [PlaceSummary]          // vm.results의 요소 타입에 맞춰서
    var isFocused: FocusState<Bool>.Binding
    
    let onBack: () -> Void
    let onSubmit: () -> Void
    let onClear: () -> Void
    let onMicTap: () -> Void
    let onSelect: (PlaceSummary) -> Void
    let onDelete: (PlaceSummary) -> Void
    @Binding var hasSubmitted: Bool
    @Binding var isPresented: Bool
    @Binding var isDestination: Bool
    let isLoading: Bool
    
    @State private var submittedQuery: String = ""
    @State private var selectedItem: PlaceSummary?
    @State private var isSelected: Bool = false
    
    @ObservedObject var store: LocationStore
    
    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                header
                list
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            if results.isEmpty && query.isEmpty && !isSelected {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused.wrappedValue = true
                }
            }
        }
//        .onChange(of: hasSubmitted) { _, newValue in
//            if newValue {
//                submittedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
//            }
//        }
        .onChange(of: results) { _, newResults in
            if !newResults.isEmpty && !query.isEmpty {
                submittedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
    
    private var header: some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                Image("gotoback")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            
            SearchBar(
                text: $query,
                isFocused: isFocused,
                onSubmit: onSubmit,
                onMicTap: onMicTap,
                onClearTap: onClear
            )
        }
        .padding(.leading, 8)
        .padding(.trailing, 20)
        .padding(.vertical, 8)
    }
    
    private var list: some View {
        GeometryReader { geo in
            ScrollView {
                VStack {
                    // 검색 전 (제출 전)
                    if !hasSubmitted {
                        VStack {
                            HStack {
                                Spacer()
                                    .frame(width: 20)
                                Text("최근 검색")
                                    .font(.premed16Scaled)
                                    .foregroundStyle(.primaryblack)
                                Spacer()
                            }
                            LazyVStack(spacing: 8) {
                                ForEach(store.locations) { item in
                                    RecentCard(
                                        title: item.name,
                                        onSelect: {
                                            isSelected = true
                                            onSelect(item)
                                        },
                                        onDelete: { onDelete(item) }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            Spacer(minLength: 0)
                        }
                        
                        // 로딩 중
                    } else if isLoading {
                        Spacer(minLength: 0)
                        
                        ProgressView()
                            .controlSize(.large)
                            .scaleEffect(1.5)
                            .padding(.top, -100)
                            .tint(.greyDisable)
                        
                        Spacer(minLength: 0)
                        
                        // 검색어는 있지만 결과가 없을 때
                    } else if results.isEmpty {
                        Spacer(minLength: 0)
                        
                        VStack(spacing: 6) {
                            Text("검색 결과가 없어요.")
                                .font(.presemi24)
                                .foregroundStyle(.greyHeavy)
                            Text("찾고 있는 장소를 다시 검색해 주세요.")
                                .font(.prereg20)
                                .foregroundStyle(.greyHeavy)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.top, -100)
                        
                        Spacer(minLength: 0)
                        
                    } else {
                        LazyVStack(spacing: 7) {
                            ForEach(results) { item in
                                PlaceCard(
                                    title: item.name,
                                    address: item.address,
                                    searchQuery: submittedQuery
                                ) {
                                    // onTap
                                    selectedItem = item
                                    isPresented = true
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                // 스크롤 뷰의 가시 영역 높이를 최소 높이로 잡아 중앙 정렬이 가능하게 함
                .frame(maxWidth: .infinity, minHeight: results.isEmpty || !hasSubmitted || isLoading ? geo.size.height : 0)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .fullScreenCover(isPresented: $isPresented) {
            if let selectedItem = selectedItem {
                LocationMap(
                    isPresented: $isPresented,
                    isDestination: $isDestination,
                    location: selectedItem,
                    onSelect: {
                        isPresented = false
                        onSelect(selectedItem)
                    },
                )
            }
        }
    }
}
