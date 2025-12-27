import Foundation
import SwiftUI

struct MagnetItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var date: Date
    var location: String
    var latitude: Double?
    var longitude: Double?
    var imagePath: String
    var gifPath: String?
    var notes: String
    
    var isGIF: Bool {
        gifPath != nil
    }
    
    var hasValidCoordinates: Bool {
        latitude != nil && longitude != nil
    }
    
    init(id: UUID = UUID(), name: String, date: Date = Date(), location: String = "未知位置", latitude: Double? = nil, longitude: Double? = nil, imagePath: String, gifPath: String? = nil, notes: String = "") {
        self.id = id
        self.name = name
        self.date = date
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.imagePath = imagePath
        self.gifPath = gifPath
        self.notes = notes
    }
}

struct MagnetGroup: Identifiable, Hashable {
    var id: String { title }
    let title: String
    let subtitle: String
    let items: [MagnetItem]
    let color: Color

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(items)
    }

    static func == (lhs: MagnetGroup, rhs: MagnetGroup) -> Bool {
        lhs.title == rhs.title && 
        lhs.subtitle == rhs.subtitle && 
        lhs.items == rhs.items
    }
}

enum GroupingMode {
    case location
    case time
}
