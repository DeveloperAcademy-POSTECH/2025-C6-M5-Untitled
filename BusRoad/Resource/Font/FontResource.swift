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
    
    static var papermed16: Font {
        return .paper(type: .medium, size: 16)
    }
}
 
    

