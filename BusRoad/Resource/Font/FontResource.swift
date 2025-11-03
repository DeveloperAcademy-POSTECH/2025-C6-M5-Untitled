import Foundation
import SwiftUI

extension Font {
    //MARK: 프리텐다드
    enum Pre {
        case bold
        case semibold
        case regular
        case medium
        
        var value: String {
            switch self {
                
            case .bold:
                return "Pretendard-Bold"
            case .semibold:
                return "Pretendard-SemiBold"
            case .regular:
                return "Pretendard-Regular"
            case .medium:
                return "Pretendard-Medium"
                
            }
        }
    }

    static func pre(type: Pre, size: CGFloat) -> Font {
        return .custom(type.value, size: size)
    }
    
    static var prebold36: Font {
        return .pre(type: .bold, size: 36)
    }
    
    static var presemi36: Font {
        return .pre(type: .semibold, size: 36)
    }
    
    static var presemi32: Font {
        return .pre(type: .semibold, size: 32)
    }
    
    static var presemi28: Font {
        return .pre(type: .semibold, size: 28 )
    }
    
    static var presemi24: Font {
        return .pre(type: .semibold, size:24)
    }
    
    static var presemi20: Font {
        return .pre(type: .semibold, size:20)
    }
    
    static var presemi18: Font {
        return .pre(type: .semibold, size:18)
    }
    
    static var premed32: Font {
        return .pre(type: .medium, size: 32)
    }
    
    static var premed28: Font {
        return .pre(type: .medium, size: 28)
    }
    
    static var premed24: Font {
        return .pre(type: .medium, size: 24)
    }
    
    static var premed20: Font {
        return .pre(type: .medium, size: 20)
    }
    
    static var premed12: Font {
        return .pre(type: .medium, size: 12)
    }
    
    static var prereg36: Font {
        return .pre(type: .regular, size: 36)
    }
    
    static var prereg32: Font {
        return .pre(type: .regular, size: 32)
    }
    
    static var prereg24: Font {
        return .pre(type: .regular, size: 24)
    }
    
    static var prereg20: Font {
        return .pre(type: .regular, size: 20)
    }
    
    static var prereg18: Font {
        return .pre(type: .regular, size: 18)
    }
    
    static var prereg16: Font {
        return .pre(type: .regular, size: 16)
    }
    
    
    
    
    // MARK: - 페이퍼로지
    enum Paper {
        case semibold
        case medium
        
        var value: String {
            switch self {
            case .semibold:
                return "Paperlogy-6SemiBold"
            case .medium:
                return "Paperlogy-5Medium"
                
                
            }
        }
    }
    
    static func paper(type: Paper, size: CGFloat) -> Font {
        return .custom(type.value, size: size)
    }
    
    static var papersemi36: Font {
        return .paper(type: .semibold, size: 36)
    }
    
    static var papermed18: Font {
        return .paper(type: .medium, size: 18)
    }
}
 
    

// MARK: - 반응형 폰트 (화면 크기에 맞게 자동 조정)
extension Font {
    /// 화면 크기에 맞게 조정된 커스텀 폰트
    static func preScaled(type: Pre, size: CGFloat) -> Font {
        .custom(type.value, size: size.wScaled)
    }
    
    static func paperScaled(type: Paper, size: CGFloat) -> Font {
        .custom(type.value, size: size.wScaled)
    }
    
    
    // 프리텐다드 - 스케일링 버전
    static var prebold36Scaled: Font {
        return .preScaled(type: .bold, size: 36)
    }
    
    static var presemi36Scaled: Font {
        return .preScaled(type: .semibold, size: 36)
    }
    
    static var presemi32Scaled: Font {
        return .preScaled(type: .semibold, size: 32)
    }
    
    static var presemi28Scaled: Font {
        return .preScaled(type: .semibold, size: 28)
    }
    
    static var presemi24Scaled: Font {
        return .preScaled(type: .semibold, size: 24)
    }
    
    static var presemi20Scaled: Font {
        return .preScaled(type: .semibold, size: 20)
    }
    
    static var presemi18Scaled: Font {
        return .preScaled(type: .semibold, size: 18)
    }
    
    static var premed32Scaled: Font {
        return .preScaled(type: .medium, size: 32)
    }
    
    static var premed28Scaled: Font {
        return .preScaled(type: .medium, size: 28)
    }
    
    static var premed24Scaled: Font {
        return .preScaled(type: .medium, size: 24)
    }
    
    static var premed12Scaled: Font {
        return .preScaled(type: .medium, size: 12)
    }
    
    static var premed20Scaled: Font {
        return .preScaled(type: .medium, size: 20)
    }
    
    static var prereg36Scaled: Font {
        return .preScaled(type: .regular, size: 36)
    }
    
    static var prereg32Scaled: Font {
        return .preScaled(type: .regular, size: 32)
    }
    
    static var prereg24Scaled: Font {
        return .preScaled(type: .regular, size: 24)
    }
    
    static var prereg20Scaled: Font {
        return .preScaled(type: .regular, size: 20)
    }
    
    static var prereg18Scaled: Font {
        return .preScaled(type: .regular, size: 18)
    }
    
    static var prereg16Scaled: Font {
        return .preScaled(type: .regular, size: 16)
    }
    
    // 페이퍼로지 - 스케일링 버전
    static var papersemi36Scaled: Font {
        return .paperScaled(type: .semibold, size: 36)
    }
    
    static var papermed18Scaled: Font {
        return .paperScaled(type: .medium, size: 18)
    }
}


extension UIFont {
    
    static func pretendard(_ type: Font.Pre, size: CGFloat) -> UIFont {
        return UIFont(name: type.value, size: size) ?? .systemFont(ofSize: size)
    }
    
    static var presemi24Scaled: UIFont {
        pretendard(.semibold, size: 24.wScaled)
    }
    
    static var presemi32Scaled: UIFont {
        pretendard(.semibold, size: 32.wScaled)
    }
    
    static var presemi36Scaled: UIFont {
        pretendard(.semibold, size: 36.wScaled)
    }
    
}
    
