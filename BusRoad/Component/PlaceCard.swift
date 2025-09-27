import SwiftUI

struct PlaceCard: View {
    let title: String
    let address: String
    var searchQuery: String? 
    var onTap: (() -> Void)?    // 카드 탭 액션

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 6) {
                
                if let query = searchQuery, !query.isEmpty {
                    Text(title.highlightedText(searchQuery: query))
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.white))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(address)")
    }
}

// MARK: - 텍스트 하이라이트 헬퍼
extension String {
    /// 검색어와 일치하는 부분을 찾아서 AttributedString으로 변환
    func highlightedText(searchQuery: String, highlightColor: Color = .green) -> AttributedString {
        var attributedString = AttributedString(self)
        
        guard !searchQuery.isEmpty else { return attributedString }
        
        let lowercasedText = self.lowercased()
        let lowercasedQuery = searchQuery.lowercased()
        
        var searchStartIndex = lowercasedText.startIndex
        
        while let range = lowercasedText.range(of: lowercasedQuery, range: searchStartIndex..<lowercasedText.endIndex) {
            // AttributedString의 범위로 변환
            if let attributedRange = Range(range, in: attributedString) {
                // 하이라이트 색상 및 굵기 적용
                attributedString[attributedRange].foregroundColor = highlightColor
                attributedString[attributedRange].font = .system(.headline, design: .default, weight: .bold)
            }
            
            // 다음 검색을 위해 시작 인덱스 업데이트
            searchStartIndex = range.upperBound
        }
        
        return attributedString
    }
}

#Preview {
    VStack(spacing: 12) {
        PlaceCard(
            title: "포항 영일대해수욕장",
            address: "경북 포항시 북구 두호동 685",
            searchQuery: "포항"
        )
        PlaceCard(
            title: "테라로사 포스텍점",
            address: "포항시 남구 청암로 87",
            searchQuery: "포항"
        )
        PlaceCard(
            title: "일반 카드 (하이라이트 없음)",
            address: "일반 주소"
        )
    }
    .padding()
}
