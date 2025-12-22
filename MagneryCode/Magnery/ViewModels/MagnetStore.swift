import Foundation
import SwiftUI
import Combine

@MainActor
class MagnetStore: ObservableObject {
    @Published var magnets: [MagnetItem] = []
    @Published var groupingMode: GroupingMode = .location
    
    private let saveKey = "SavedMagnets"
    
    init() {
        loadMagnets()
    }
    
    func addMagnet(_ magnet: MagnetItem) {
        magnets.append(magnet)
        saveMagnets()
    }
    
    func deleteMagnet(_ magnet: MagnetItem) {
        magnets.removeAll { $0.id == magnet.id }
        saveMagnets()
    }
    
    func updateMagnet(_ magnet: MagnetItem) {
        if let index = magnets.firstIndex(where: { $0.id == magnet.id }) {
            magnets[index] = magnet
            saveMagnets()
        }
    }
    
    func groupedMagnets() -> [MagnetGroup] {
        switch groupingMode {
        case .location:
            return groupByLocation()
        case .time:
            return groupByTime()
        }
    }
    
    private func groupByLocation() -> [MagnetGroup] {
        let grouped = Dictionary(grouping: magnets) { $0.location }
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
    
    private func groupByTime() -> [MagnetGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: magnets) { magnet -> Date in
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
            
            // Migration: Add coordinates to existing magnets if missing
            var updated = false
            for i in 0..<loadedMagnets.count {
                if loadedMagnets[i].latitude == nil {
                    // Assign some coordinates based on location name for demo
                    let loc = loadedMagnets[i].location
                    if loc.contains("上海") {
                        loadedMagnets[i].latitude = 31.2304 + Double.random(in: -0.05...0.05)
                        loadedMagnets[i].longitude = 121.4737 + Double.random(in: -0.05...0.05)
                    } else if loc.contains("威海") {
                        loadedMagnets[i].latitude = 37.5097 + Double.random(in: -0.05...0.05)
                        loadedMagnets[i].longitude = 122.1157 + Double.random(in: -0.05...0.05)
                    } else if loc != "未知位置" {
                        // Default to somewhere in China if we have a location name
                        loadedMagnets[i].latitude = 35.0 + Double.random(in: -5...5)
                        loadedMagnets[i].longitude = 105.0 + Double.random(in: -10...10)
                    }
                    updated = true
                }
            }
            
            self.magnets = loadedMagnets
            if updated {
                saveMagnets()
            }
        }
    }
}
