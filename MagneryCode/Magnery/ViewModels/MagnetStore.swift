import Foundation
import SwiftUI
import Combine
import CoreLocation

struct SectionData: Identifiable {
    let id = UUID()
    let section: String
    let groups: [MagnetGroup]
}

@MainActor
class MagnetStore: ObservableObject {
    @Published var magnets: [MagnetItem] = []
    @Published var groupingMode: GroupingMode = .location
    @Published var lastAddedMagnetId: UUID?
    @Published var userName: String = "收藏家"
    @Published var userAvatarPath: String? = nil
    
    // Settings
    @Published var systemLanguage: String = "简体中文"
    @Published var captionModel: String = "通用"
    @Published var dialogueModel: String = "标准"
    
    // Cache for grouped sections to improve performance
    @Published var sections: [SectionData] = []
    
    private let saveKey = "SavedMagnets"
    private let userKey = "UserProfile"
    private let settingsKey = "AppSettings"
    
    init() {
        loadMagnets()
        loadUserProfile()
        loadSettings()
        updateSections()
    }
    
    func saveUserProfile() {
        let profile = ["name": userName, "avatar": userAvatarPath ?? ""]
        UserDefaults.standard.set(profile, forKey: userKey)
    }
    
    private func loadUserProfile() {
        if let profile = UserDefaults.standard.dictionary(forKey: userKey) {
            userName = profile["name"] as? String ?? "收藏家"
            let avatar = profile["avatar"] as? String ?? ""
            userAvatarPath = avatar.isEmpty ? nil : avatar
        }
    }
    
    func saveSettings() {
        let settings = [
            "language": systemLanguage,
            "captionModel": captionModel,
            "dialogueModel": dialogueModel
        ]
        UserDefaults.standard.set(settings, forKey: settingsKey)
    }
    
    private func loadSettings() {
        if let settings = UserDefaults.standard.dictionary(forKey: settingsKey) {
            systemLanguage = settings["language"] as? String ?? "简体中文"
            captionModel = settings["captionModel"] as? String ?? "通用"
            dialogueModel = settings["dialogueModel"] as? String ?? "标准"
        }
    }
    
    func addMagnet(_ magnet: MagnetItem) {
        magnets.append(magnet)
        lastAddedMagnetId = magnet.id
        saveMagnets()
        updateSections()
    }
    
    func deleteMagnet(_ magnet: MagnetItem) {
        magnets.removeAll { $0.id == magnet.id }
        saveMagnets()
        updateSections()
    }
    
    func updateMagnet(_ magnet: MagnetItem) {
        if let index = magnets.firstIndex(where: { $0.id == magnet.id }) {
            magnets[index] = magnet
            saveMagnets()
            updateSections()
        }
    }
    
    func toggleFavorite(_ magnet: MagnetItem) {
        if let index = magnets.firstIndex(where: { $0.id == magnet.id }) {
            var updatedMagnet = magnets[index]
            updatedMagnet.isFavorite = !(updatedMagnet.isFavorite ?? false)
            magnets[index] = updatedMagnet
            saveMagnets()
            updateSections()
        }
    }
    
    func setGroupingMode(_ mode: GroupingMode) {
        groupingMode = mode
        updateSections()
    }
    
    func updateSections() {
        let groups = groupedMagnets()
        
        if groupingMode == .time {
            let calendar = Calendar.current
            let groupedByMonth = Dictionary(grouping: groups) { group -> String in
                if let firstItem = group.items.first {
                    let components = calendar.dateComponents([.year, .month], from: firstItem.date)
                    let monthFormatter = DateFormatter()
                    monthFormatter.dateFormat = "M月份"
                    if let date = calendar.date(from: components) {
                        return monthFormatter.string(from: date)
                    }
                }
                return ""
            }
            
            let sortedSections = groupedByMonth.keys.sorted { key1, key2 in
                if let groups1 = groupedByMonth[key1], let date1 = groups1.first?.items.first?.date,
                   let groups2 = groupedByMonth[key2], let date2 = groups2.first?.items.first?.date {
                    return date1 > date2
                }
                return key1 > key2
            }
            
            self.sections = sortedSections.map { section in
                let sectionGroups = groupedByMonth[section] ?? []
                return SectionData(
                    section: section,
                    groups: sectionGroups.sorted { $0.items.first!.date > $1.items.first!.date }
                )
            }
        } else {
            let groupedByCity = Dictionary(grouping: groups) { group -> String in
                return extractCityName(from: group.title)
            }
            
            let sortedCities = groupedByCity.keys.sorted { city1, city2 in
                let count1 = groupedByCity[city1]?.reduce(0) { $0 + $1.items.count } ?? 0
                let count2 = groupedByCity[city2]?.reduce(0) { $0 + $1.items.count } ?? 0
                if count1 == count2 {
                    return city1 < city2
                }
                return count1 > count2
            }
            
            self.sections = sortedCities.map { city in
                let cityGroups = groupedByCity[city] ?? []
                return SectionData(
                    section: city,
                    groups: cityGroups.sorted { group1, group2 in
                        if group1.items.count == group2.items.count {
                            return group1.title < group2.title
                        }
                        return group1.items.count > group2.items.count
                    }
                )
            }
        }
    }
    
    private func extractCityName(from location: String) -> String {
        if location == "未知位置" {
            return "未知位置"
        }
        
        if location.contains("市") {
            if let range = location.range(of: "市") {
                return String(location[..<range.upperBound])
            }
        }
        
        if location.contains("省") {
            if let range = location.range(of: "省") {
                return String(location[..<range.upperBound])
            }
        }
        
        return location
    }
    
    func groupedMagnets(filter: ((MagnetItem) -> Bool)? = nil) -> [MagnetGroup] {
        let itemsToGroup = filter != nil ? magnets.filter(filter!) : magnets
        
        switch groupingMode {
        case .location:
            return groupByLocation(items: itemsToGroup)
        case .time:
            return groupByTime(items: itemsToGroup)
        }
    }
    
    private func groupByLocation(items: [MagnetItem]? = nil) -> [MagnetGroup] {
        let itemsToGroup = items ?? magnets
        let grouped = Dictionary(grouping: itemsToGroup) { $0.location }
        let colors: [Color] = [
            Color(red: 1.0, green: 0.95, blue: 0.6),
            Color(red: 1.0, green: 0.85, blue: 0.9),
            Color(red: 0.75, green: 0.85, blue: 1.0),
            Color(red: 0.85, green: 0.95, blue: 0.85),
            Color(red: 1.0, green: 0.9, blue: 0.75)
        ]
        
        return grouped.enumerated().map { index, pair in
            let (location, items) = pair
            return MagnetGroup(
                title: location,
                subtitle: "\(items.count)个冰箱贴",
                items: items.sorted { $0.date > $1.date },
                color: colors[index % colors.count]
            )
        }.sorted { $0.items.count > $1.items.count }
    }
    
    private func groupByTime(items: [MagnetItem]? = nil) -> [MagnetGroup] {
        let itemsToGroup = items ?? magnets
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: itemsToGroup) { magnet -> Date in
            let components = calendar.dateComponents([.year, .month, .day], from: magnet.date)
            return calendar.date(from: components)!
        }
        
        let colors: [Color] = [
            Color(red: 0.75, green: 0.85, blue: 1.0),
            Color(red: 1.0, green: 0.95, blue: 0.6),
            Color(red: 1.0, green: 0.85, blue: 0.9),
            Color(red: 0.85, green: 0.95, blue: 0.85),
            Color(red: 1.0, green: 0.9, blue: 0.75)
        ]
        
        return grouped.enumerated().map { index, pair in
            let (date, items) = pair
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "M月d日"
            
            return MagnetGroup(
                title: dateFormatter.string(from: date),
                subtitle: "\(items.count)个冰箱贴",
                items: items.sorted { $0.date > $1.date },
                color: colors[index % colors.count]
            )
        }.sorted { $0.items.first!.date > $1.items.first!.date }
    }
    
    private func saveMagnets() {
        if let encoded = try? JSONEncoder().encode(magnets) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadMagnets() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([MagnetItem].self, from: data) {
            var loadedMagnets = decoded
            
            // Migration: Add or correct coordinates for existing magnets
            var updated = false
            for i in 0..<loadedMagnets.count {
                let loc = loadedMagnets[i].location
                let currentLat = loadedMagnets[i].latitude
                
                // If coordinates are missing OR if they were assigned to the "random China" fallback (30-40 lat, 95-115 lon)
                // but we now have a specific city match, we should update them.
                let isFallback = currentLat != nil && currentLat! >= 30 && currentLat! <= 40 && loadedMagnets[i].longitude! >= 95 && loadedMagnets[i].longitude! <= 115
                
                if currentLat == nil || isFallback {
                    if let coord = LocationHelper.coordinates(for: loc) {
                        loadedMagnets[i].latitude = coord.latitude + Double.random(in: -0.02...0.02)
                        loadedMagnets[i].longitude = coord.longitude + Double.random(in: -0.02...0.02)
                        updated = true
                    } else if isFallback {
                        // If it was a fallback but we can't find a city match, 
                        // it's better to remove the coordinates entirely so it doesn't show in a random place
                        loadedMagnets[i].latitude = nil
                        loadedMagnets[i].longitude = nil
                        updated = true
                    }
                }
            }
            
            self.magnets = loadedMagnets
            if updated {
                saveMagnets()
            }
        }
    }
}
