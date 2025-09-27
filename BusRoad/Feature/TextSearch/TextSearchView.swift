import SwiftUI

// MARK: - TextSearchView
struct TextSearchView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @EnvironmentObject private var vm: TextSearchViewModel
    
    @State private var hasSubmitted = false
    @State private var isSearchMode = false
    @State private var suppressKeyboardOnce = false
    @FocusState private var isFocused: Bool
    
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
        .onChange(of: isFocused) { _, new in
            if new && !isSearchMode {
                isSearchMode = true
                DispatchQueue.main.async {
                           isFocused = true
                       }
            }
        }
        .onChange(of: vm.shouldShowSearchMode) { _, show in
            if show {
                isSearchMode = true
                hasSubmitted = true
                
                if vm.isFromVoiceSearch {
                    isFocused = false
                }
                
                vm.resetSearchMode()
            }
        }
    }
}

// MARK: - Views
private extension TextSearchView {
    /// 초기 화면 - 중앙에 큰 검색바가 있는 인트로 뷰
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
    
    /// 검색 모드 화면 - 상단 검색바 + 결과 리스트
    var searchModeView: some View {
        VStack(spacing: 12) {
            searchHeader
            searchResults
        }
    }
    
    /// 검색 모드 상단 헤더 - 뒤로가기 버튼 + 컴팩트 검색바
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
    
    /// 검색 결과 영역 - 빈 결과 메시지 또는 장소 리스트
    var searchResults: some View {
        VStack {
            if vm.results.isEmpty && !vm.query.isEmpty == false  {
                Text("")
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
                            // TODO: 탭하면 경로추천뷰로 넘어가도록
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    /// 검색바 생성 함수 - compact 모드에 따라 크기 조절
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

// MARK: - Actions
private extension TextSearchView {
    /// 검색 모드 종료 - 인트로 화면으로 돌아가며 모든 상태 초기화
    func exitSearchMode() {
        isSearchMode = false
        isFocused = false
        hasSubmitted = false
        vm.query = ""
        vm.results = []
    }
    
    /// 실제 검색 수행 - API 호출 및 결과 표시
    func performSearch() {
        isSearchMode = true
        hasSubmitted = true
        Task { await vm.search() }
        // isFocused는 그대로 true 유지 - 키보드 계속 나와있음
    }
    
    /// 검색어 및 결과 지우기 - X 버튼 탭 시 호출
    func clearSearch() {
        vm.query = ""
        vm.results = []
        hasSubmitted = false
        isFocused = true // 지운 후에도 바로 재입력 가능하게 포커스 유지
    }
}

// MARK: - SearchBar
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "검색어를 입력하세요"
    @FocusState.Binding var isFocused: Bool
    
    var compact: Bool = false          // 컴팩트 모드 여부
    var onSubmit: (() -> Void)?        // 검색 실행 콜백
    var onMicTap: (() -> Void)?        // 마이크 버튼 탭 콜백
    var onClearTap: (() -> Void)?      // 지우기 버튼 탭 콜백
    
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

// MARK: - SearchBar Components
private extension SearchBar {
    /// 왼쪽 돋보기 아이콘
    var searchIcon: some View {
        Image(systemName: "magnifyingglass")
            .foregroundStyle(.secondary)
    }
    
    /// 중앙 텍스트 입력 필드
    var textField: some View {
        TextField(placeholder, text: $text)
            .focused($isFocused)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .submitLabel(.search)
            .onSubmit { onSubmit?() }
        
    }
    
    /// 오른쪽 액션 버튼 - 텍스트가 없으면 마이크, 있으면 X버튼
    var actionButton: some View {
        Button {
            if text.isEmpty {
                onMicTap?()
            } else {
                onClearTap?()
            }
        } label: {
            Image(systemName: text.isEmpty ? "mic.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.black)
                .padding(6)
                .animation(nil, value: text.isEmpty)
                .frame(width:44, height:44)
        }
        .buttonStyle(.plain)
    }
    
    /// 검색바 배경 스타일
    var searchBarBackground: some View {
        RoundedRectangle(cornerRadius: compact ? 14 : 16)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    TextSearchView()
        .environmentObject(NavigationCoordinator())
        .environmentObject(TextSearchViewModel())
}
