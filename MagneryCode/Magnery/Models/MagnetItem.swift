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
    var modelPath: String?
    var notes: String
    
    var isGIF: Bool {
        gifPath != nil
    }

    var is3D: Bool {
        modelPath != nil
    }
    
    var hasValidCoordinates: Bool {
        latitude != nil && longitude != nil
    }
    
    var imageFallbackURLs: [URL] {
        guard imagePath.hasPrefix("http") else { return [] }
        
        // Extract base URL from imagePath if possible
        let baseURL: String
        if let url = URL(string: imagePath) {
            baseURL = url.deletingLastPathComponent().absoluteString + "/"
        } else {
            baseURL = "https://magnery-1259559729.cos.ap-shanghai.myqcloud.com/magnery_resources/"
        }
        
        var urls: [URL] = []
        let extensions = ["jpg", "JPG", "png", "PNG", "jpeg", "JPEG"]
        
        // 1. Try variations of the imagePath base name
        let imageBaseName = (imagePath as NSString).lastPathComponent.components(separatedBy: ".").first ?? ""
        if !imageBaseName.isEmpty {
            for ext in extensions {
                let fallbackURLString = baseURL + imageBaseName + "." + ext
                if let url = URL(string: fallbackURLString), url.absoluteString != imagePath {
                    if !urls.contains(url) {
                        urls.append(url)
                    }
                }
            }
        }
        
        // 2. Try variations of the modelPath base name
        if let modelPath = modelPath, !modelPath.isEmpty {
            let modelBaseName = (modelPath as NSString).lastPathComponent.components(separatedBy: ".").first ?? ""
            if !modelBaseName.isEmpty {
                for ext in extensions {
                    let fallbackURLString = baseURL + modelBaseName + "." + ext
                    if let url = URL(string: fallbackURLString), url.absoluteString != imagePath {
                        if !urls.contains(url) {
                            urls.append(url)
                        }
                    }
                }
            }
        }
        return urls
    }
    
    var imageURL: URL? {
        URL(string: imagePath)
    }
    
    init(id: UUID = UUID(), name: String, date: Date = Date(), location: String = "未知位置", latitude: Double? = nil, longitude: Double? = nil, imagePath: String, gifPath: String? = nil, modelPath: String? = nil, notes: String = "") {
        self.id = id
        self.name = name
        self.date = date
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.imagePath = imagePath
        self.gifPath = gifPath
        self.modelPath = modelPath
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
