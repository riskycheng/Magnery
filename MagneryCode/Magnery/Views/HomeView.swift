import SwiftUI

enum HomeMode {
    case camera
    case map
}

struct HomeView: View {
    @EnvironmentObject var store: MagnetStore
    @Namespace private var modeNamespace
    @State private var showingCamera = false
    @State private var ringRotation: Double = 0
    @State private var dotScale: CGFloat = 1.0
    @State private var scrollOffset: CGFloat = 0
    @State private var isCollapsed = false
    @State private var lastScrollUpdate: CGFloat = 0
    @State private var homeMode: HomeMode = .camera
    @State private var hasTriggeredHaptic = false
    @State private var selectedGroupForNavigation: MagnetGroup?
    @State private var lastAddedIdForNavigation: UUID?
    
    private let collapsedThreshold: CGFloat = 200
    private let maxHeaderHeight: CGFloat = 360
    private let scrollUpdateThreshold: CGFloat = 2  // Only update every 2 points for smoother animation
    
    private var visualProgress: CGFloat {
        let rawProgress = 1.0 + (scrollOffset / 150.0)
        return min(1.0, max(0.0, rawProgress))
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                // Main scrollable content
                ScrollView {
                    VStack(spacing: 0) {
                        // Visual elements that scroll away (Camera Ring / Map)
                        ZStack {
                            cameraButton
                                .opacity(homeMode == .camera ? 1 : 0)
                                .scaleEffect(homeMode == .camera ? 1 : 0.9)
                            
                            mapViewContainer
                                .opacity(homeMode == .map ? 1 : 0)
                                .scaleEffect(homeMode == .map ? 1 : 0.9)
                        }
                        .frame(height: 300) // Increased from 260 to 300
                        .padding(.top, 110) 
                        .opacity(visualProgress)
                        .scaleEffect(0.8 + (0.2 * visualProgress))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: homeMode)
                        
                        VStack(spacing: 0) {
                            // Mode and Grouping toggle
                            modeAndGroupingToggle
                                .padding(.top, 20)
                                .padding(.bottom, 10)
                            
                            // Content list
                            contentList
                        }
                        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                    }
                    .background(
                        GeometryReader { geometry in
                            let offset = geometry.frame(in: .named("scroll")).minY
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self, value: offset)
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    handleScroll(value)
                }
                
                // Fixed Header Layer (Text content that docks)
                headerLayer
                    .zIndex(1)
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView()
            }
            .navigationDestination(item: $selectedGroupForNavigation) { group in
                ListView(group: group, scrollToGroup: true, scrollToItemId: lastAddedIdForNavigation)
            }
            .onChange(of: store.lastAddedMagnetId) { oldValue, newValue in
                if let newId = newValue {
                    // Find the group this magnet belongs to
                    let groups = store.groupedMagnets()
                    if let group = groups.first(where: { g in g.items.contains(where: { $0.id == newId }) }) {
                        lastAddedIdForNavigation = newId
                        selectedGroupForNavigation = group
                    }
                    // Reset the ID in store so we don't trigger again
                    store.lastAddedMagnetId = nil
                }
            }
        }
    }
    
    private var headerLayer: some View {
        let rawProgress = 1.0 + (scrollOffset / 100.0)
        let progress = min(1.0, max(0.0, rawProgress))
        let isDocked = scrollOffset < -80
        
        // Use continuous values for smoother transitions without explicit animation
        let titleSize = 16.0 + (12.0 * progress)
        let verticalSpacing = 1.0 + (4.0 * progress)
        
        // Instead of changing alignment (which is expensive), we use a fixed alignment 
        // and adjust the layout based on progress.
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .center, spacing: verticalSpacing) {
                    Text(greeting)
                        .font(.system(size: titleSize, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: progress > 0.5 ? .center : .leading)
                    
                    ZStack {
                        // Expanded subtitle
                        Text("真棒！已经收集了\(store.magnets.count)个冰箱贴，走过\(uniqueLocationsCount)个城市")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .opacity(Double(max(0, (progress - 0.5) * 2)))
                        
                        // Collapsed subtitle (Stats)
                        HStack(spacing: 4) {
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 8))
                            Text("\(store.magnets.count)个收藏")
                            Text("·")
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 8))
                            Text("\(uniqueLocationsCount)个城市")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .opacity(Double(max(0, (0.5 - progress) * 2)))
                    }
                    .frame(maxWidth: .infinity, alignment: progress > 0.5 ? .center : .leading)
                }
                
                if isDocked {
                    // Quick camera button only when docked
                    Button(action: { 
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        showingCamera = true 
                    }) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.orange)
                            .clipShape(Circle())
                            .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 44) + (30 * progress))
            .padding(.bottom, 15 + (15 * progress))
            .background(
                Color(red: 0.95, green: 0.95, blue: 0.97)
            )
            .overlay(
                Rectangle()
                    .fill(Color.black.opacity(0.05))
                    .frame(height: 0.5)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .opacity(isDocked ? 1 : 0)
            )
        }
        .ignoresSafeArea(edges: .top)
    }
    
    private func handleScroll(_ value: CGFloat) {
        // Only update if the change is significant enough to reduce re-renders
        if abs(value - lastScrollUpdate) < scrollUpdateThreshold {
            return
        }
        
        lastScrollUpdate = value
        scrollOffset = value
        
        let threshold: CGFloat = -100
        let newCollapsed = value < threshold
        
        if newCollapsed != isCollapsed {
            isCollapsed = newCollapsed
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred(intensity: newCollapsed ? 0.8 : 0.5)
        }
    }
    
    private var mapViewContainer: some View {
        MapView()
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .padding(.top, 15)
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
                .frame(width: 200, height: 200) // Increased from 180 to 200 to accommodate stroke width
                .rotationEffect(.degrees(ringRotation), anchor: .center)
            
            // Dots with pulsing animation
            ForEach(0..<8) { index in
                Circle()
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: 6, height: 6)
                    .scaleEffect(dotScale)
                    .offset(y: -125) // Adjusted from -115 to -125
                    .rotationEffect(.degrees(Double(index) * 45))
            }
            .onAppear {
                // Infinite rotation: slower (12s) and continuous
                ringRotation = 0
                withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                    ringRotation = 360
                }
                // Pulsing dots animation
                dotScale = 1.0
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    dotScale = 1.3
                }
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
        }
        .padding(.bottom, 20)
        .padding(.top, 15)
    }
    
    
    private var contentList: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(store.sections) { sectionData in
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
    }
    
    private var modeAndGroupingToggle: some View {
        HStack(spacing: 12) {
            // Mode Switcher (Camera / Map) - Custom Segmented Control
            HStack(spacing: 0) {
                ForEach([HomeMode.camera, HomeMode.map], id: \.self) { mode in
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            homeMode = mode
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: mode == .camera ? "camera.fill" : "map.fill")
                                .font(.system(size: 12, weight: .bold))
                            
                            if homeMode == mode {
                                Text(mode == .camera ? "相机" : "地图")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                            }
                        }
                        .foregroundColor(homeMode == mode ? .white : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            ZStack {
                                if homeMode == mode {
                                    Capsule()
                                        .fill(Color.black)
                                        .matchedGeometryEffect(id: "modeTab", in: modeNamespace)
                                }
                            }
                        )
                    }
                }
            }
            .padding(4)
            .background(Color.black.opacity(0.05))
            .clipShape(Capsule())
            
            Spacer()
            
            // Grouping Toggle (Location / Time) - Refined Pill
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    store.setGroupingMode(store.groupingMode == .location ? .time : .location)
                }
            }) {
                HStack(spacing: 8) {
                    ZStack {
                        Image(systemName: "mappin.and.ellipse")
                            .opacity(store.groupingMode == .location ? 1 : 0)
                            .scaleEffect(store.groupingMode == .location ? 1 : 0.5)
                        Image(systemName: "calendar")
                            .opacity(store.groupingMode == .time ? 1 : 0)
                            .scaleEffect(store.groupingMode == .time ? 1 : 0.5)
                    }
                    .font(.system(size: 12, weight: .bold))
                    
                    Text(store.groupingMode == .location ? "按地点" : "按日期")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                )
            }
        }
        .padding(.horizontal, 20)
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
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: groupingMode == .location ? "mappin.circle.fill" : "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(group.title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Text(group.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(group.items.prefix(12)) { item in
                        ZStack {
                            if let gifPath = item.gifPath {
                                GIFView(url: ImageManager.shared.getFileURL(for: gifPath))
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else if let image = ImageManager.shared.loadImage(filename: item.imagePath) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                }
            }
        }
        .padding(20)
        .background(group.color)
        .clipShape(RoundedRectangle(cornerRadius: 24))
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
