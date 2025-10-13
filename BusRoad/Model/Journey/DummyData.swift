//
//  DummyJourney.swift
//  BusRoad
//
//  Created by 박난 on 10/14/25.
//

/*
 사용 예시
 #Preview {
 WholeJourney(journey: DummyData.journey)
 }
 
 DummyData.journey, busNode, walkNode 존재
 */
struct DummyData {
    static let journey: Journey = {
        Journey(
            totalTime: 52,
            nodes: [
                // MARK: - 0. Walk: 현위치 → 포스텍
                .walk(
                    WalkRouteNode(
                        start: LocationInfo(
                            name: "현위치",
                            latitude: 36.01744477662011,
                            longitude: 129.322173630262
                        ),
                        end: LocationInfo(
                            name: "포스텍",
                            latitude: 36.016052,
                            longitude: 129.324623
                        ),
                        travelTime: 4
                    )
                ),
                
                // MARK: - 1. Bus: 포스텍 → 육거리
                .bus(
                    BusRouteNode(
                        start: LocationInfo(
                            name: "포스텍",
                            latitude: 36.016052,
                            longitude: 129.324623
                        ),
                        end: LocationInfo(
                            name: "육거리",
                            latitude: 36.039709,
                            longitude: 129.366421
                        ),
                        busNo: "207",
                        busId: 2803975,
                        stations: [
                            BusStation(index: 0, stationId: 420124, stationName: "포스텍", stationCityCode: 4100, localStationId: "PHB350099016"),
                            BusStation(index: 1, stationId: 420125, stationName: "생명공학연구소", stationCityCode: 4100, localStationId: "PHB350099017"),
                            BusStation(index: 2, stationId: 420126, stationName: "효곡동행정복지센터", stationCityCode: 4100, localStationId: "PHB350099018"),
                            BusStation(index: 3, stationId: 420031, stationName: "효자아트홀", stationCityCode: 4100, localStationId: "PHB350000024"),
                            BusStation(index: 4, stationId: 420032, stationName: "효자웰빙아울렛", stationCityCode: 4100, localStationId: "PHB350000025"),
                            BusStation(index: 5, stationId: 420027, stationName: "포항성모병원", stationCityCode: 4100, localStationId: "PHB350000020"),
                            BusStation(index: 6, stationId: 420037, stationName: "대잠사거리", stationCityCode: 4100, localStationId: "PHB350000027"),
                            BusStation(index: 7, stationId: 420061, stationName: "시외버스터미널", stationCityCode: 4100, localStationId: "PHB350092019"),
                            BusStation(index: 8, stationId: 420062, stationName: "교보생명", stationCityCode: 4100, localStationId: "PHB350092020"),
                            BusStation(index: 9, stationId: 420136, stationName: "산업은행", stationCityCode: 4100, localStationId: "PHB351012016"),
                            BusStation(index: 10, stationId: 420385, stationName: "고용복지플러스센터", stationCityCode: 4100, localStationId: "PHB351012010"),
                            BusStation(index: 11, stationId: 420386, stationName: "GS슈퍼마켓", stationCityCode: 4100, localStationId: "PHB351012011"),
                            BusStation(index: 12, stationId: 420387, stationName: "죽도파출소", stationCityCode: 4100, localStationId: "PHB351012012"),
                            BusStation(index: 13, stationId: 420388, stationName: "홈플러스(오거리)", stationCityCode: 4100, localStationId: "PHB351012013"),
                            BusStation(index: 14, stationId: 420375, stationName: "죽도시장", stationCityCode: 4100, localStationId: "PHB351011004"),
                            BusStation(index: 15, stationId: 420339, stationName: "육거리", stationCityCode: 4100, localStationId: "PHB351008001")
                        ],
                        travelTime: 25
                    )
                ),
                
                // MARK: - 2. Walk: 육거리 → 육거리
                .walk(
                    WalkRouteNode(
                        start: LocationInfo(name: "육거리", latitude: 36.039709, longitude: 129.366421),
                        end: LocationInfo(name: "육거리", latitude: 36.039709, longitude: 129.366421),
                        travelTime: 0
                    )
                ),
                
                // MARK: - 3. Bus: 육거리 → 포항역(흥해행)
                .bus(
                    BusRouteNode(
                        start: LocationInfo(name: "육거리", latitude: 36.039709, longitude: 129.366421),
                        end: LocationInfo(name: "포항역(흥해행)", latitude: 36.072384, longitude: 129.341965),
                        busNo: "305",
                        busId: 2805909,
                        stations: [
                            BusStation(index: 0, stationId: 420339, stationName: "육거리", stationCityCode: 4100, localStationId: "PHB351008001"),
                            BusStation(index: 1, stationId: 420350, stationName: "북부시장", stationCityCode: 4100, localStationId: "PHB351009011"),
                            BusStation(index: 2, stationId: 420349, stationName: "선린병원", stationCityCode: 4100, localStationId: "PHB351009010"),
                            BusStation(index: 3, stationId: 420352, stationName: "선린병원후문", stationCityCode: 4100, localStationId: "PHB351009013"),
                            BusStation(index: 4, stationId: 420417, stationName: "대동우방아파트", stationCityCode: 4100, localStationId: "PHB351014002"),
                            BusStation(index: 5, stationId: 420429, stationName: "유성여자고등학교", stationCityCode: 4100, localStationId: "PHB351014017"),
                            BusStation(index: 6, stationId: 414956, stationName: "영신고등학교", stationCityCode: 4100, localStationId: "PHB351014028"),
                            BusStation(index: 7, stationId: 420430, stationName: "포항 중앙고등학교", stationCityCode: 4100, localStationId: "PHB351014018"),
                            BusStation(index: 8, stationId: 426407, stationName: "중앙고->달전", stationCityCode: 4100, localStationId: "PHB351001788"),
                            BusStation(index: 9, stationId: 426441, stationName: "달전(무정차)", stationCityCode: 4100, localStationId: "PHB351001797"),
                            BusStation(index: 10, stationId: 426357, stationName: "흥해농협달전지점", stationCityCode: 4100, localStationId: "PHB350099418"),
                            BusStation(index: 11, stationId: 420318, stationName: "삼도드림파크", stationCityCode: 4100, localStationId: "PHB351001058"),
                            BusStation(index: 12, stationId: 426358, stationName: "포항역(흥해행)", stationCityCode: 4100, localStationId: "PHB351001794")
                        ],
                        travelTime: 22
                    )
                ),
                
                // MARK: - 4. Walk: 포항역(흥해행) → 포항역 (고속철도)
                .walk(
                    WalkRouteNode(
                        start: LocationInfo(name: "포항역(흥해행)", latitude: 36.072384, longitude: 129.341965),
                        end: LocationInfo(name: "포항역 (고속철도)", latitude: 36.0716843, longitude: 129.3419644),
                        travelTime: 1
                    )
                )
            ],
            routeType: "추천"
        )
    }()
    
    static let walkNode = WalkRouteNode(
        start: LocationInfo(
            name: "현위치",
            latitude: 36.01744477662011,
            longitude: 129.322173630262
        ),
        end: LocationInfo(
            name: "포스텍",
            latitude: 36.016052,
            longitude: 129.324623
        ),
        travelTime: 4
    )
    
    static let busNode = BusRouteNode(
        start: LocationInfo(
            name: "포스텍",
            latitude: 36.016052,
            longitude: 129.324623
        ),
        end: LocationInfo(
            name: "육거리",
            latitude: 36.039709,
            longitude: 129.366421
        ),
        busNo: "207",
        busId: 2803975,
        stations: [
            BusStation(index: 0, stationId: 420124, stationName: "포스텍", stationCityCode: 4100, localStationId: "PHB350099016"),
            BusStation(index: 1, stationId: 420125, stationName: "생명공학연구소", stationCityCode: 4100, localStationId: "PHB350099017"),
            BusStation(index: 2, stationId: 420126, stationName: "효곡동행정복지센터", stationCityCode: 4100, localStationId: "PHB350099018"),
            BusStation(index: 3, stationId: 420031, stationName: "효자아트홀", stationCityCode: 4100, localStationId: "PHB350000024"),
            BusStation(index: 4, stationId: 420032, stationName: "효자웰빙아울렛", stationCityCode: 4100, localStationId: "PHB350000025"),
            BusStation(index: 5, stationId: 420027, stationName: "포항성모병원", stationCityCode: 4100, localStationId: "PHB350000020"),
            BusStation(index: 6, stationId: 420037, stationName: "대잠사거리", stationCityCode: 4100, localStationId: "PHB350000027"),
            BusStation(index: 7, stationId: 420061, stationName: "시외버스터미널", stationCityCode: 4100, localStationId: "PHB350092019"),
            BusStation(index: 8, stationId: 420062, stationName: "교보생명", stationCityCode: 4100, localStationId: "PHB350092020"),
            BusStation(index: 9, stationId: 420136, stationName: "산업은행", stationCityCode: 4100, localStationId: "PHB351012016"),
            BusStation(index: 10, stationId: 420385, stationName: "고용복지플러스센터", stationCityCode: 4100, localStationId: "PHB351012010"),
            BusStation(index: 11, stationId: 420386, stationName: "GS슈퍼마켓", stationCityCode: 4100, localStationId: "PHB351012011"),
            BusStation(index: 12, stationId: 420387, stationName: "죽도파출소", stationCityCode: 4100, localStationId: "PHB351012012"),
            BusStation(index: 13, stationId: 420388, stationName: "홈플러스(오거리)", stationCityCode: 4100, localStationId: "PHB351012013"),
            BusStation(index: 14, stationId: 420375, stationName: "죽도시장", stationCityCode: 4100, localStationId: "PHB351011004"),
            BusStation(index: 15, stationId: 420339, stationName: "육거리", stationCityCode: 4100, localStationId: "PHB351008001")
        ],
        travelTime: 25
    )
}
