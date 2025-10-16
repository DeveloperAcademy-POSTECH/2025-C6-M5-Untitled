////
////  LocationLiveTesterView.swift
////  BusRoad
////
////  Created by Ella's Mac on 10/14/25.
////
//
import SwiftUI

struct LocationLiveTesterView: View {
    @StateObject private var vm: LocationLiveTesterVM
    
  
    @MainActor
    init(locationService: LocationService) {
        _vm = StateObject(wrappedValue: LocationLiveTesterVM(locationService: locationService))
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("실시간 위치 테스트").font(.title3).bold()

            Group {
                HStack { Text("상태"); Spacer(); Text(vm.statusText) }
                HStack { Text("좌표"); Spacer(); Text(vm.coordText).monospaced() }
                HStack { Text("정확도"); Spacer(); Text(vm.accuracyText) }
                HStack { Text("속도"); Spacer(); Text(vm.speedText) }
                HStack { Text("업데이트"); Spacer(); Text(vm.timestampText) }
            }
            .font(.callout)
            .padding(.horizontal, 12)

            HStack {
                Button("1회 요청") { vm.requestOnce() }
                Button(vm.isUpdating ? "중지" : "시작") {
                    vm.isUpdating ? vm.stop() : vm.start()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .onReceive(vm.locationPublisher) { loc in
            guard let loc else { return }
            vm.apply(loc)
        }
    }
}

#Preview {
    LocationLiveTesterView(locationService: LocationService())
}
