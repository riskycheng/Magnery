import Foundation
import CoreLocation

struct LocationHelper {
    /// Returns coordinates for a given location string if it matches a known city or district.
    static func coordinates(for location: String) -> CLLocationCoordinate2D? {
        let loc = location.lowercased()
        
        // Mapping of common Chinese cities/districts to coordinates
        let cityMap: [String: CLLocationCoordinate2D] = [
            "上海": CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
            "北京": CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
            "广州": CLLocationCoordinate2D(latitude: 23.1291, longitude: 113.2644),
            "深圳": CLLocationCoordinate2D(latitude: 22.5431, longitude: 114.0579),
            "杭州": CLLocationCoordinate2D(latitude: 30.2741, longitude: 120.1551),
            "淳安": CLLocationCoordinate2D(latitude: 29.6028, longitude: 119.0425), // Qiandao Lake
            "苏州": CLLocationCoordinate2D(latitude: 31.2990, longitude: 120.5853),
            "南京": CLLocationCoordinate2D(latitude: 32.0603, longitude: 118.7969),
            "成都": CLLocationCoordinate2D(latitude: 30.5728, longitude: 104.0668),
            "西安": CLLocationCoordinate2D(latitude: 34.3416, longitude: 108.9398),
            "武汉": CLLocationCoordinate2D(latitude: 30.5928, longitude: 114.3055),
            "长沙": CLLocationCoordinate2D(latitude: 28.2282, longitude: 112.9388),
            "重庆": CLLocationCoordinate2D(latitude: 29.5630, longitude: 106.5516),
            "天津": CLLocationCoordinate2D(latitude: 39.0842, longitude: 117.2009),
            "厦门": CLLocationCoordinate2D(latitude: 24.4798, longitude: 118.0894),
            "青岛": CLLocationCoordinate2D(latitude: 36.0671, longitude: 120.3826),
            "威海": CLLocationCoordinate2D(latitude: 37.5097, longitude: 122.1157),
            "大理": CLLocationCoordinate2D(latitude: 25.6065, longitude: 100.2676),
            "丽江": CLLocationCoordinate2D(latitude: 26.8721, longitude: 100.2273),
            "三亚": CLLocationCoordinate2D(latitude: 18.2525, longitude: 109.5119),
            "昆明": CLLocationCoordinate2D(latitude: 24.8801, longitude: 102.8329),
            "福州": CLLocationCoordinate2D(latitude: 26.0745, longitude: 119.2965),
            "无锡": CLLocationCoordinate2D(latitude: 31.4912, longitude: 120.3119),
            "宁波": CLLocationCoordinate2D(latitude: 29.8683, longitude: 121.5440),
            "合肥": CLLocationCoordinate2D(latitude: 31.8206, longitude: 117.2272),
            "郑州": CLLocationCoordinate2D(latitude: 34.7466, longitude: 113.6253),
            "济南": CLLocationCoordinate2D(latitude: 36.6512, longitude: 117.1201),
            "哈尔滨": CLLocationCoordinate2D(latitude: 45.8038, longitude: 126.5349),
            "长春": CLLocationCoordinate2D(latitude: 43.8171, longitude: 125.3235),
            "沈阳": CLLocationCoordinate2D(latitude: 41.6772, longitude: 123.4631)
        ]
        
        // Check for partial matches (e.g., "杭州市" matches "杭州")
        for (name, coord) in cityMap {
            if loc.contains(name.lowercased()) {
                return coord
            }
        }
        
        return nil
    }
}
