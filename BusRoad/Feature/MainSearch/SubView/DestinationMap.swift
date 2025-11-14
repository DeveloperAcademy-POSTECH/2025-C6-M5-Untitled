import SwiftUI
import MapKit
import CoreLocation

// MARK: - Deprecation 수정된 DestinationMap 뷰

struct DestinationMap: View {
    @Binding var isPresented: Bool
    let onSelect: () -> Void
    let destination: PlaceSummary
    
    @State private var position: MapCameraPosition
    
    private var showInformation: Bool = true
    
    init(isPresented: Binding<Bool>, destination: PlaceSummary, onSelect: @escaping () -> Void) {
        self._isPresented = isPresented
        self.destination = destination
        self.onSelect = onSelect
        
        self._position = State(initialValue: .region(MKCoordinateRegion(
            center: destination.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
        )))
    }
    
    var body: some View {
        VStack(spacing:0){
            ZStack(alignment: .bottom) {
                Map(position: $position) {
                    Annotation("", coordinate: destination.coordinate) {
                        Image("marker")
                            .offset(y: -15)
                    }
                }
                .ignoresSafeArea()
                .frame(maxHeight: .infinity)
                
                .overlay(alignment: .topTrailing) {
                    Button {isPresented = false} label: {Image("white.xbutton")}
                        .padding(.top, 53.wScaled)
                        .padding(.trailing, 12.wScaled)
                        .ignoresSafeArea()
                }
                
                .onChange(of: destination.coordinate.latitude) {
                    // 위도나 경도가 변경되면 region 업데이트
                    position = .region(MKCoordinateRegion(
                        center: destination.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
                .onChange(of: destination.coordinate.longitude) {
                    // 위도나 경도가 변경되면 region 업데이트
                    position = .region(MKCoordinateRegion(
                        center: destination.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
            ZStack{
                Rectangle()
                    .frame(height: 205.wScaled)
                    .clipShape(
                        .rect(
                            topLeadingRadius: 15,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 15
                        )
                    )
                    .foregroundColor(.primarywhite)
                    .padding(.bottom, 0)
                VStack(spacing: 0){
                    VStack(alignment: .leading, spacing: 9){
                        Text(destination.name)
                            .font(.presemi28Scaled)
                            .foregroundStyle(Color.greyHeavy)
                        Text(destination.address)
                            .font(.prereg20Scaled)
                            .foregroundStyle(Color.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 30.wScaled)
                    .padding(.bottom, 25.wScaled)
                    .padding(.top, 30.wScaled)
                    Button(action: {
                        onSelect()
                        isPresented = false
                    }) {
                        Text("목적지로 설정")
                            .font(.premed28Scaled)
                            .foregroundColor(.subLight)
                            .padding(.horizontal, 96.wScaled)
                            .padding(.vertical, 13.5.wScaled)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .foregroundColor(Color.subPoint)
                            )
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}
// --- 프리뷰 ---

struct DestinationMap_Previews: PreviewProvider {
    // 포항공과대학교 (POSTECH) 위치 정보 정의
    static let postechLocation = PlaceSummary(
        name: "포항공과대학교",
        address: "포항 청암로 77",
        latitude: 36.0097,
        longitude: 129.3400
    )
    @State static var isPresentedPreview = true
    
    static var previews: some View {
        NavigationView {
            DestinationMap(
                isPresented: $isPresentedPreview,
                destination: postechLocation,
                onSelect: {
                    print("\(postechLocation.name)이(가) 선택되었습니다.")
                }
            )
        }
    }
}
