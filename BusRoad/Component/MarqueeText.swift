import SwiftUI

public struct MarqueeText: View {
    public var text: String
    public var font: Font
    public var uiFont: UIFont  // 👈 추가: 크기 계산용 UIFont
    public var startDelay: Double
    public var alignment: Alignment
    
    @State private var animate = false
    var isCompact = false
    
    public var body: some View {
        let stringWidth = text.widthOfString(usingFont: uiFont)
        let stringHeight = text.heightOfString(usingFont: uiFont)
        
        GeometryReader { geo in
            let needsScrolling = (stringWidth > geo.size.width)
            let offsetDistance = max(stringWidth - geo.size.width, 0)
            
            let animation = Animation
                .linear(duration: Double(offsetDistance) / 30)
                .delay(startDelay)
                .repeatForever(autoreverses: true)
            
            ZStack {
                if needsScrolling {
                    Text(text)
                        .lineLimit(1)
                        .font(font)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(width: stringWidth, height: stringHeight, alignment: .leading)
                        .offset(x: animate ? -offsetDistance : 0)
                        .animation(animate ? animation : nil, value: animate)
                        .frame(width: geo.size.width, alignment: .leading)
                        .clipped()
                } else {
                    Text(text)
                        .font(font)
                        .frame(width: geo.size.width, height: stringHeight, alignment: alignment)
                }
            }
            .onAppear {
                if needsScrolling {
                    DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
                        self.animate = true
                    }
                }
            }
            .onChange(of: text) { _, newValue in
                let newStringWidth = newValue.widthOfString(usingFont: uiFont)
                let newNeedsScrolling = newStringWidth > geo.size.width
                
                self.animate = false
                
                if newNeedsScrolling {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.animate = true
                    }
                }
            }
        }
        .frame(height: stringHeight)
    }
    
    public init(
        text: String,
        font: Font,
        uiFont: UIFont,  // 👈 추가
        startDelay: Double = 1.0,
        alignment: Alignment? = nil
    ) {
        self.text = text
        self.font = font
        self.uiFont = uiFont
        self.startDelay = startDelay
        self.alignment = alignment ?? .leading
    }
}

extension MarqueeText {
    public func makeCompact(_ compact: Bool = true) -> Self {
        var view = self
        view.isCompact = compact
        return view
    }
}

extension String {
    func widthOfString(usingFont font: UIFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: fontAttributes)
        return size.width
    }
    
    func heightOfString(usingFont font: UIFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: fontAttributes)
        return size.height
    }
}
#Preview {
    VStack(spacing: 30) {
        MarqueeText(
            text: "죽전역.포은아트홀.죽전2동행정복지센터.신세계사우스시티",
            font: .premed28Scaled,
            uiFont: UIFont.pretendard(.medium, size: 28.wScaled),
            startDelay: 1.0,
            alignment: .leading
        )
        .frame(width: 300)
        
        MarqueeText(
            text: "포스텍 정문",
            font: .premed28Scaled,
            uiFont: UIFont.pretendard(.medium, size: 28.wScaled),
            startDelay: 1.0,
            alignment: .leading
        )
        .frame(width: 300)
    }
    .padding()
}
