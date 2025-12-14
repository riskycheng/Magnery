import Foundation
import SwiftUI

struct MagnetItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var date: Date
    var location: String
    var imagePath: String
    var notes: String
    
    init(id: UUID = UUID(), name: String, date: Date = Date(), location: String = "未知位置", imagePath: String, notes: String = "") {
        self.id = id
        self.name = name
        self.date = date
        self.location = location
        self.imagePath = imagePath
        self.notes = notes
    }
}

struct MagnetGroup: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let items: [MagnetItem]
    let color: Color
}

enum GroupingMode {
    case location
    case time
}
