import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: MagnetStore
    @State private var showingCamera = false
    @State private var ringRotation: Double = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isCollapsed = false
    @State private var lastScrollUpdate: CGFloat = 0
    
    private let collapsedThreshold: CGFloat = 200
    private let maxHeaderHeight: CGFloat = 320
    private let scrollUpdateThreshold: CGFloat = 2  // Only update every 2 points for smoother animation
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Collapsed header (shown when scrolled)
                    collapsedHeader
                    
                    // Main scrollable content
                    ScrollView {
                        VStack(spacing: 0) {
                            // Expanded header content
                            expandedHeaderContent
                            
                            // Grouping toggle
                            groupingToggle
                                .padding(.top, 20)
                                .padding(.bottom, 10)
                            
                            // Content list
                            contentList
                        }
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: geometry.frame(in: .named("scroll")).minY
                                    )
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        // Only update if the change is significant to reduce redraws
                        let difference = abs(value - lastScrollUpdate)
                        let newCollapsed = value < -collapsedThreshold
                        
                        // Always update if collapse state changes, otherwise throttle updates
                        if newCollapsed != isCollapsed {
                            // State change - update immediately
                            isCollapsed = newCollapsed
                            scrollOffset = value
                            lastScrollUpdate = value
                            
                            // Haptic feedback
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        } else if difference > scrollUpdateThreshold {
                            // Normal scroll - throttle updates, no animation
                            scrollOffset = value
                            lastScrollUpdate = value
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView()
            }
        }
    }
    
    // Collapsed header shown when scrolled down
    private var collapsedHeader: some View {
        HStack {
            Text(greeting)
                .font(.caption)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        .opacity(isCollapsed ? 1 : 0)
        .offset(y: isCollapsed ? 0 : -50)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isCollapsed)
    }
    
    // Expanded header content with camera button
    private var expandedHeaderContent: some View {
        VStack(spacing: 20) {
            headerView
            cameraButton
        }
        .frame(height: maxHeaderHeight)
        .padding(.top, 20)
        .opacity(isCollapsed ? 0 : 1)  // Simple show/hide instead of complex calculations
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text(greeting)
                .font(.title)
                .fontWeight(.medium)
            
            Text("真棒！已经收集了\(store.magnets.count)个冰箱贴，走过\(uniqueLocationsCount)个城市")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var cameraButton: some View {
        ZStack {
            ColorfulRing()
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(ringRotation), anchor: .center)
                .onAppear {
                    withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                        ringRotation = 360
                    }
                }
            
            // Dots simplified for performance
            ForEach(0..<8) { index in
                Circle()
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: 6, height: 6)
                    .offset(y: -115)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
            
            Circle()
                .fill(Color.white)
                .frame(width: 80, height: 80)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            Button(action: {
                showingCamera = true
            }) {
                Image(systemName: "camera")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.black)
            }
            // Camera scale animation removed for better performance
        }
        .padding(.vertical, 40)
    }
    
    
    private var contentList: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(groupedBySection(), id: \.section) { sectionData in
                VStack(alignment: .leading, spacing: 12) {
                    if !sectionData.section.isEmpty {
                        Text(sectionData.section)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                    }
                    
                    ForEach(sectionData.groups) { group in
                        NavigationLink(destination: ListView(group: group, scrollToGroup: true)) {
                            GroupCard(group: group, groupingMode: store.groupingMode)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 40)
        .id(store.groupingMode)  // Only re-render when grouping mode changes
    }
    
    private var groupingToggle: some View {
        HStack {
            Spacer()
            Button(action: {
                store.groupingMode = store.groupingMode == .location ? .time : .location
            }) {
                HStack(spacing: 6) {
                    Image(systemName: store.groupingMode == .location ? "mappin" : "calendar")
                        .font(.system(size: 14))
                    Text(store.groupingMode == .location ? "按地点" : "按日期")
                        .font(.subheadline)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal)
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<6: return "凌晨好 :-)"
        case 6..<12: return "早上好 :-)"
        case 12..<18: return "下午好 :-)"
        default: return "晚上好 :-)"
        }
    }
    
    private var uniqueLocationsCount: Int {
        Set(store.magnets.map { $0.location }).count
    }
    
    private func groupedBySection() -> [SectionData] {
        let groups = store.groupedMagnets()
        
        if store.groupingMode == .time {
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
            
            // Sort dictionary keys first to ensure stable ordering
            let sortedSections = groupedByMonth.keys.sorted { key1, key2 in
                // Extract dates for comparison
                if let groups1 = groupedByMonth[key1], let date1 = groups1.first?.items.first?.date,
                   let groups2 = groupedByMonth[key2], let date2 = groups2.first?.items.first?.date {
                    return date1 > date2
                }
                return key1 > key2
            }
            
            return sortedSections.map { section in
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
            
            // Sort dictionary keys first to ensure stable ordering
            let sortedCities = groupedByCity.keys.sorted { city1, city2 in
                let count1 = groupedByCity[city1]?.reduce(0) { $0 + $1.items.count } ?? 0
                let count2 = groupedByCity[city2]?.reduce(0) { $0 + $1.items.count } ?? 0
                if count1 == count2 {
                    // If counts are equal, sort by city name for stability
                    return city1 < city2
                }
                return count1 > count2
            }
            
            return sortedCities.map { city in
                let cityGroups = groupedByCity[city] ?? []
                return SectionData(
                    section: city,
                    groups: cityGroups.sorted { group1, group2 in
                        if group1.items.count == group2.items.count {
                            // If counts are equal, sort by title for stability
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
                let cityName = String(location[..<range.upperBound])
                return cityName
            }
        }
        
        if location.contains("省") {
            if let range = location.range(of: "省") {
                return String(location[..<range.upperBound])
            }
        }
        
        return location
    }
}

struct SectionData {
    let section: String
    let groups: [MagnetGroup]
}

struct ColorfulRing: View {
    let colors: [Color] = [
        Color(red: 1.0, green: 0.4, blue: 0.6),
        Color(red: 0.4, green: 0.8, blue: 0.5),
        Color(red: 1.0, green: 0.8, blue: 0.3),
        Color(red: 0.5, green: 0.6, blue: 1.0),
        Color(red: 0.8, green: 0.5, blue: 1.0)
    ]
    
    var body: some View {
        ZStack {
            ForEach(0..<colors.count, id: \.self) { index in
                Circle()
                    .trim(from: CGFloat(index) / CGFloat(colors.count),
                          to: CGFloat(index + 1) / CGFloat(colors.count) + 0.01)
                    .stroke(colors[index], style: StrokeStyle(lineWidth: 16, lineCap: .round))
            }
        }
        .rotationEffect(.degrees(-90))
    }
}

struct GroupCard: View {
    let group: MagnetGroup
    let groupingMode: GroupingMode
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: groupingMode == .location ? "mappin.circle.fill" : "calendar")
                        .foregroundColor(.primary)
                    Text(group.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Text(group.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                ForEach(group.items.prefix(2)) { item in
                    if let image = ImageManager.shared.loadImage(filename: item.imagePath) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding()
        .background(group.color)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// PreferenceKey for tracking scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    HomeView()
        .environmentObject(MagnetStore())
}
