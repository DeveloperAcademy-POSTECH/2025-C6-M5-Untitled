import SwiftUI

// MARK: - GeometryReader 없이 사용 가능한 간단한 스케일링
extension CGFloat {
    /// 화면 너비 기준 스케일 (기준: iPhone 16 = 393pt)
    var wScaled: CGFloat {
        let baseWidth: CGFloat = 393
        // 첫 window의 screen 사용 (iOS 26 호환)
        let screenWidth: CGFloat = {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                return windowScene.screen.bounds.width
            }
            return 393 
        }()
        
        let scale: CGFloat = screenWidth / baseWidth
        let clampedScale: CGFloat = Swift.min(Swift.max(scale, 0.85), 1.15)
        return self * clampedScale
    }
    
    func minimum(_ minValue: CGFloat) -> CGFloat {
        Swift.max(self, minValue)
    }
}

extension Double {
    var wScaled: CGFloat { CGFloat(self).wScaled }
}

extension Int {
    var wScaled: CGFloat { CGFloat(self).wScaled }
}
