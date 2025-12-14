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
        let grouped = Dictionary(grouping: magnets) { magnet -> String in
            let components = calendar.dateComponents([.year, .month], from: magnet.date)
            return "\(components.year!)年\(components.month!)月"
        }
        
        let colors: [Color] = [
            Color(red: 0.75, green: 0.85, blue: 1.0),
            Color(red: 1.0, green: 0.95, blue: 0.6),
            Color(red: 1.0, green: 0.85, blue: 0.9),
            Color(red: 0.85, green: 0.95, blue: 0.85),
            Color(red: 1.0, green: 0.9, blue: 0.75)
        ]
        
        return grouped.enumerated().map { index, pair in
            let (period, items) = pair
            let sortedItems = items.sorted { $0.date > $1.date }
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "M月d日"
            
            return MagnetGroup(
                title: dateFormatter.string(from: sortedItems.first!.date),
                subtitle: "\(items.count)个冰箱贴",
                items: sortedItems,
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
            magnets = decoded
        }
    }
}
