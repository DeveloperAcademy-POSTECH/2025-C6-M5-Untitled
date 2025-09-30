import Foundation

private enum _SecretsLoader {
    static func string(for key: String) -> String {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
            let value = dict[key] as? String
        else {
            #if DEBUG
            assertionFailure("🚨 Secrets.plist에서 \(key) 값을 찾지 못했습니다.")
            #endif
            return ""
        }
        return value
    }
}

enum Secrets {
    static let odsayApiKey       = _SecretsLoader.string(for: "ODSAY_API_KEY")
    static let naverClientId     = _SecretsLoader.string(for: "NAVER_CLIENT_ID")
    static let naverClientSecret = _SecretsLoader.string(for: "NAVER_CLIENT_SECRET")
}
