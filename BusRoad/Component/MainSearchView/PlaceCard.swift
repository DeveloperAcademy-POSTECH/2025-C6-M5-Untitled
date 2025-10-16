import SwiftUI

struct PlaceCard: View {
    let title: String
    let address: String
    var searchQuery: String? 
    var onTap: () -> Void    // 카드 탭 액션

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 5) {
                
                if let query = searchQuery, !query.isEmpty {
                    Text(title.highlightedText(searchQuery: query))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.presemi24)
                        .foregroundStyle(.primaryHeavy)
                    
                    
                } else {
                    Text(title)
                        .font(.presemi24)
                        .foregroundStyle(.primaryHeavy)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text(address)
                    .font(.prereg18)
                    .foregroundStyle(.greyNormal)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 22)
            .padding(.horizontal, 23)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(.primaryWhite))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.01), radius: 5, x: 0, y: 0)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 15))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(address)")
    }
}

// TODO: extension은 파일 따로 만들기

// MARK: - 텍스트 하이라이트 헬퍼
extension String {
    /// 검색어와 일치하는 부분을 찾아서 AttributedString으로 변환
    func highlightedText(searchQuery: String, highlightColor: Color = Color.subPoint) -> AttributedString {
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
                attributedString[attributedRange].font = .presemi24
            }
            
            // 다음 검색을 위해 시작 인덱스 업데이트
            searchStartIndex = range.upperBound
        }
        
        return attributedString
    }
}

#Preview {
    VStack(spacing: 7) {
        PlaceCard(
            title: "포항 영일대해수욕장",
            address: "경북 포항시 북구 두호동 685",
            searchQuery: "포항",
            onTap: {}
        )
        PlaceCard(
            title: "테라로사 포스텍점",
            address: "포항시 남구 청암로 87",
            searchQuery: "포항",
            onTap: {}
        )
        PlaceCard(
            title: "일반 카드 (하이라이트 없음)",
            address: "일반 주소",
            onTap: {}
        )
    }
    .padding()
}
