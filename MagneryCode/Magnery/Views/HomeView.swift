import SwiftUI

enum HomeMode {
    case camera
    case map
}

struct HomeView: View {
    @EnvironmentObject var store: MagnetStore
    @State private var showingCamera = false
    @State private var ringRotation: Double = 0
    @State private var dotScale: CGFloat = 1.0
    @State private var scrollOffset: CGFloat = 0
    @State private var isCollapsed = false
    @State private var lastScrollUpdate: CGFloat = 0
    @State private var homeMode: HomeMode = .camera
    @State private var hasTriggeredHaptic = false
    
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
                        .frame(height: 260)
                        .padding(.top, 120) // Restored to previous spacing
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
            
            Spacer(minLength: 0)
        }
        .frame(height: isDocked ? nil : 140)
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
            .padding(.vertical, 20)
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
            
            // Dots with pulsing animation
            ForEach(0..<8) { index in
                Circle()
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: 6, height: 6)
                    .scaleEffect(dotScale)
                    .offset(y: -115)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
            .onAppear {
                // Infinite rotation: slower (12s) and continuous
                withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                    ringRotation = 360
                }
                // Pulsing dots animation
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
        .padding(.vertical, 40)
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
        HStack {
            Button(action: {
                withAnimation(.spring()) {
                    homeMode = homeMode == .camera ? .map : .camera
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: homeMode == .camera ? "map" : "camera")
                        .font(.system(size: 14))
                    Text(homeMode == .camera ? "地图" : "相机")
                        .font(.subheadline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            
            Spacer()
            
            if homeMode == .camera {
                Button(action: {
                    store.setGroupingMode(store.groupingMode == .location ? .time : .location)
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
