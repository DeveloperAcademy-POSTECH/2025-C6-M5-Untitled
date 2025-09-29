import SwiftUI

extension MainSearchView {

    /// 검색 모드 종료
    func exitSearchMode() {
        isSearchMode = false
        isFocused = false
        hasSubmitted = false
        vm.query = ""
        vm.results = []
    }

    /// 검색 실행
    func performSearch() {
        isSearchMode = true
        hasSubmitted = true
        Task { await vm.search() }
        // 포커스 유지(키보드 열린 상태)
    }

    /// 검색어/결과 지우기
    func clearSearch() {
        vm.query = ""
        vm.results = []
        hasSubmitted = false
        isFocused = true // 지운 후 재입력 편의
    }
}
