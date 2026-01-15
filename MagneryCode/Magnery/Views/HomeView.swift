import SwiftUI

enum HomeMode {
    case camera
    case map
}

struct HomeView: View {
    @EnvironmentObject var store: MagnetStore
    @Binding var selectedTab: Tab
    @Namespace private var modeNamespace
    @State private var showingCamera = false
    @State private var ringRotation: Double = 0
    @State private var dotScale: CGFloat = 1.0
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.0
    @State private var scrollOffset: CGFloat = 0
    @State private var initialOffset: CGFloat? = nil
    @State private var isCollapsed = false
    @State private var lastScrollUpdate: CGFloat = 0
    @State private var homeMode: HomeMode = .camera
    @State private var hasTriggeredHaptic = false
    @State private var selectedGroupForNavigation: MagnetGroup?
    @State private var selectedMagnetForNavigation: MagnetItem?
    @State private var lastAddedIdForNavigation: UUID?
    @State private var rippleScale: CGFloat = 1.0
    @State private var rippleOpacity: Double = 0.0
    @State private var bgRippleLocation: CGPoint = .zero
    @State private var bgRippleScale: CGFloat = 1.0
    @State private var bgRippleOpacity: Double = 0.0
    @State private var groupingDragOffset: CGFloat = 0
    @State private var isDraggingGrouping = false
    @State private var modeDragOffset: CGFloat = 0
    @State private var isDraggingMode = false
    
    private let collapsedThreshold: CGFloat = 200
    private let maxHeaderHeight: CGFloat = 360
    private let scrollUpdateThreshold: CGFloat = 1  // Reduced threshold
    
    private var visualProgress: CGFloat {
        let rawProgress = 1.0 + (scrollOffset / 150.0)
        return min(1.0, max(0.0, rawProgress))
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { outerGeo in
                ZStack(alignment: .top) {
                    Color(red: 0.95, green: 0.95, blue: 0.97)
                        .ignoresSafeArea()
                    
                    // Main scrollable content
                    ScrollView {
                        VStack(spacing: 0) {
                            // Visual elements that scroll away (Camera Ring / Map)
                            ZStack {
                                cameraButton
                                    .opacity(homeMode == .camera ? 1.0 : 0.0)
                                    .scaleEffect(homeMode == .camera ? 1.0 : 0.9)
                                
                                mapViewContainer
                                    .opacity(homeMode == .map ? 1.0 : 0.0)
                                    .scaleEffect(homeMode == .map ? 1.0 : 0.9)
                            }
                            .frame(height: 280) 
                            .padding(.top, 90) 
                            .opacity(visualProgress)
                            .scaleEffect(0.85 + (0.15 * visualProgress))
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: homeMode)
                            
                            VStack(spacing: 0) {
                                // Mode and Grouping toggle
                                modeAndGroupingToggle
                                    .padding(.top, 28)
                                    .padding(.bottom, 8)
                                
                                // Content list
                                contentList
                            }
                        }
                        .background(
                            GeometryReader { geo in
                                let offset = geo.frame(in: .global).minY - outerGeo.frame(in: .global).minY
                                Color.clear
                                    .onAppear {
                                        if initialOffset == nil {
                                            initialOffset = offset
                                        }
                                    }
                                    .onChange(of: offset) { newValue in
                                        let calibratedOffset = newValue - (initialOffset ?? newValue)
                                        handleScroll(calibratedOffset)
                                    }
                            }
                        )
                    }
                    
                    // Fixed Header Layer (Text content that docks)
                    headerLayer
                        .zIndex(1)
                }
                .setTabBarVisibility(true)
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView()
            }
            .navigationDestination(item: $selectedGroupForNavigation) { group in
                ListView(group: group, scrollToGroup: true, scrollToItemId: lastAddedIdForNavigation)
            }
            .navigationDestination(item: $selectedMagnetForNavigation) { magnet in
                DetailView(magnet: magnet)
            }
            .onChange(of: store.lastAddedMagnetId) { oldValue, newValue in
                if let newId = newValue {
                    // Navigate directly to DetailView for the new item
                    if let magnet = store.magnets.first(where: { $0.id == newId }) {
                        selectedMagnetForNavigation = magnet
                    }
                    // Reset the ID in store so we don't trigger again
                    store.lastAddedMagnetId = nil
                }
            }
        }
    }
    
    private var headerLayer: some View {
        let rawProgress = 1.0 + (scrollOffset / 120.0)
        let progress = min(1.0, max(0.0, rawProgress))
        let isDocked = scrollOffset < -70
        
        let titleSize = 18.0 + (16.0 * progress)
        let verticalSpacing = 2.0 + (6.0 * progress)
        
        return VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                // Expanded Title Area (Leading)
                VStack(alignment: .leading, spacing: verticalSpacing) {
                    Text(greeting)
                        .font(Font.system(size: titleSize, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .scaleEffect(progress > 0.4 ? 1.0 : 0.8, anchor: .leading)
                    
                    HStack(spacing: 4) {
                        Text("已收集")
                        Text("\(store.magnets.count)")
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("个冰箱贴")
                    }
                    .font(Font.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.8))
                }
                .opacity(progress > 0.4 ? Double((progress - 0.4) * 2.5) : 0.0)
                .offset(x: (1.0 - progress) * 15)
                
                // Docked Content (Centered Title)
                VStack(spacing: 1) {
                    Text(store.userName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    
                    Text("\(store.magnets.count) 个收藏")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .opacity(progress < 0.35 ? Double((0.35 - progress) * 3) : 0.0)
                .offset(y: 5)
                
                // Camera Button (Right Aligned)
                HStack {
                    Spacer()
                    Button(action: { 
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        showingCamera = true 
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 40, height: 40)
                                .shadow(color: .black.opacity(0.08), radius: 8)
                            
                            // Style matching the large central icon
                            ZStack {
                                Image(systemName: "viewfinder")
                                    .font(Font.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black.opacity(0.8))
                                
                                Circle()
                                    .fill(Color(red: 0.1, green: 0.75, blue: 0.5))
                                    .frame(width: 4.5, height: 4.5)
                            }
                        }
                    }
                    .padding(.trailing, 4) // Slight padding for visual balance
                    .opacity(progress < 0.3 ? Double((0.3 - progress) * 4) : 0.0)
                    .scaleEffect(progress < 0.3 ? 1.0 : 0.8)
                }
            }
            .padding(.top, 60)
            .padding(.horizontal, 20) // Standard alignment with other views
            .padding(.bottom, 15)
            .background(
                ZStack {
                    if isDocked {
                        BlurView(style: .systemUltraThinMaterialLight)
                            .ignoresSafeArea()
                    }
                }
            )
            .overlay(
                Rectangle()
                    .fill(Color.black.opacity(0.05))
                    .frame(height: 0.5)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .opacity(isDocked ? 1.0 : 0.0)
            )
        }
        .ignoresSafeArea(edges: .top)
    }
    
    private func handleScroll(_ value: CGFloat) {
        if abs(value - scrollOffset) < scrollUpdateThreshold {
            return
        }
        
        scrollOffset = value
        
        let threshold: CGFloat = -60
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
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 25, x: 0, y: 12)
            .padding(.horizontal, 24)
    }
    
    private var cameraButton: some View {
        ZStack {
            // Background Tap Area for "Water Surface" ripples
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { location in
                    triggerBackgroundRipple(at: location)
                }
            
            // Dynamic Pulsing Rings - Staggered and more pronounced
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseScale + CGFloat(i) * 0.5)
                    .opacity(pulseOpacity * (1.0 - Double(i) * 0.3))
            }
            
            // Interactive Water Ripple Effect (Central)
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.black.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 130, height: 130)
                    .scaleEffect(rippleScale + CGFloat(i) * 0.2)
                    .opacity(rippleOpacity * (1.0 - Double(i) * 0.3))
            }
            
            // Background Ripple (at touch point)
            ZStack {
                ForEach(0..<2) { i in
                    Circle()
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        .frame(width: 40, height: 40)
                        .scaleEffect(bgRippleScale + CGFloat(i) * 0.4)
                        .opacity(bgRippleOpacity * (1.0 - Double(i) * 0.5))
                }
            }
            .position(bgRippleLocation)
            
            Button(action: {
                triggerRippleEffect()
                let impact = UIImpactFeedbackGenerator(style: .heavy)
                impact.impactOccurred()
                
                // Guaranteed minimum animation time (0.6s) before transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showingCamera = true
                }
            }) {
                ZStack {
                    // Main Button Body - Enlarged
                    Circle()
                        .fill(.white)
                        .frame(width: 130, height: 130)
                        .shadow(color: .black.opacity(0.08), radius: 35, x: 0, y: 18)
                    
                    // Rotating Focus Ring - Enlarged
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(
                            LinearGradient(colors: [.black.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(ringRotation))
                    
                    Circle()
                        .trim(from: 0.5, to: 0.8)
                        .stroke(
                            LinearGradient(colors: [.black.opacity(0.2), .clear], startPoint: .bottom, endPoint: .top),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-ringRotation * 0.5))
                    
                    // Minimalist Viewfinder Icon - Enlarged
                    ZStack {
                        Image(systemName: "viewfinder")
                            .font(Font.system(size: 52, weight: .light))
                            .foregroundColor(.black.opacity(0.8))
                            .scaleEffect(1.0 + Double(dotScale - 1.0) * 2.0)
                        
                        Circle()
                            .fill(Color(red: 0.1, green: 0.75, blue: 0.5))
                            .frame(width: 8, height: 8)
                            .opacity(pulseOpacity > 0.2 ? 1.0 : 0.5)
                    }
                }
            }
            .scaleEffect(dotScale)
        }
        .onAppear {
            // Faster, more obvious animations
            
            // 1. Continuous Rotation for Focus Rings
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            
            // 2. Pronounced Breathing for the Button
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                dotScale = 1.05
            }
            
            // 3. Staggered Pulsing Waves
            withAnimation(.easeOut(duration: 2.5).repeatForever(autoreverses: false)) {
                pulseScale = 2.5
                pulseOpacity = 0.0
            }
            
            // Reset pulse opacity for the loop
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                pulseOpacity = 0.6
            }
        }
    }
    
    
    private var contentList: some View {
        Group {
            if store.sections.isEmpty {
                emptyStateView
            } else {
                ZStack(alignment: .top) {
                    LazyVStack(alignment: .leading, spacing: 40) {
                        ForEach(store.sections) { sectionData in
                            VStack(alignment: .leading, spacing: 24) {
                                if !sectionData.section.isEmpty {
                                    Text(AttributedString(sectionData.section, attributes: AttributeContainer([
                                        .font: Font.system(size: 12, weight: .bold, design: .monospaced),
                                        .tracking: 3.0
                                    ])))
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(.horizontal, 32)
                                }
                                
                                ForEach(sectionData.groups) { group in
                                    NavigationLink(destination: ListView(group: group, scrollToGroup: true)) {
                                        GroupCard(group: group, groupingMode: store.groupingMode)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.horizontal, 24)
                                }
                            }
                        }
                    }
                    .id(store.groupingMode)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
                .padding(.top, 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: store.groupingMode)
            }
        }
        .padding(.bottom, 160)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("开启收藏之旅")
                        .font(Font.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("捕捉美好瞬间，或在社区寻找灵感。")
                        .font(Font.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    showingCamera = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                        Text("立即捕捉")
                    }
                    .font(Font.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.orange)
                            .shadow(color: .orange.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
                }
                
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTab = .community
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe.asia.australia.fill")
                        Text("探索社区")
                    }
                    .font(Font.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .contentShape(Capsule())
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.05))
                    )
                }
            }
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.03), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }
    
    private var modeAndGroupingToggle: some View {
        HStack(spacing: 12) {
            modeSwitcher
            
            Spacer()
            
            groupingSwitcher
        }
        .padding(.horizontal, 24)
    }
    
    private var modeSwitcher: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.black.opacity(0.04))
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.02), lineWidth: 0.5)
                )
            
            HStack(spacing: 0) {
                ForEach([HomeMode.camera, HomeMode.map], id: \.self) { mode in
                    modeSegment(for: mode)
                }
            }
            .background(modeSelectionIndicator)
        }
        .frame(width: 140) 
        .clipShape(Capsule())
        .gesture(modeDragGesture)
    }

    private func modeSegment(for mode: HomeMode) -> some View {
        HStack(spacing: 6) {
            Image(systemName: mode == .camera ? "viewfinder" : "map.fill")
                .font(Font.system(size: 13, weight: .bold))
            
            if homeMode == mode {
                Text(mode == .camera ? "相机" : "地图")
                    .font(Font.system(size: 13, weight: .bold, design: .rounded))
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .foregroundColor(homeMode == mode ? .primary : .secondary.opacity(0.8))
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .contentShape(Rectangle())
        .onTapGesture {
            guard homeMode != mode else { return }
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                homeMode = mode
            }
        }
    }

    private var modeSelectionIndicator: some View {
        GeometryReader { geo in
            let width = geo.size.width / 2
            let baseOffset = homeMode == .camera ? 2.0 : width + 2.0
            let finalOffset = isDraggingMode ? 
                min(max(2, modeDragOffset - (width/2)), width*2 - width + 2) : 
                baseOffset
                
            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                .frame(width: width - 4)
                .offset(x: finalOffset)
        }
    }

    private var modeDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDraggingMode {
                    isDraggingMode = true
                }
                modeDragOffset = value.location.x
                
                let midPoint = 70.0 // Half of 140
                if value.location.x < midPoint && homeMode == .map {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        homeMode = .camera
                    }
                } else if value.location.x > midPoint && homeMode == .camera {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        homeMode = .map
                    }
                }
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isDraggingMode = false
                }
            }
    }
    
    private var groupingSwitcher: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.black.opacity(0.04))
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.02), lineWidth: 0.5)
                )
            
            HStack(spacing: 0) {
                ForEach([GroupingMode.location, GroupingMode.time], id: \.self) { mode in
                    groupingSegment(for: mode)
                }
            }
            .background(groupingSelectionIndicator)
        }
        .frame(width: 140)
        .clipShape(Capsule())
        .gesture(groupingDragGesture)
    }

    private func groupingSegment(for mode: GroupingMode) -> some View {
        HStack(spacing: 6) {
            Image(systemName: mode == .location ? "mappin.and.ellipse" : "calendar")
                .font(Font.system(size: 13, weight: .bold))
            
            if store.groupingMode == mode {
                Text(mode == .location ? "地点" : "日期")
                    .font(Font.system(size: 13, weight: .bold, design: .rounded))
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .foregroundColor(store.groupingMode == mode ? .primary : .secondary.opacity(0.8))
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .contentShape(Rectangle())
        .onTapGesture {
            guard store.groupingMode != mode else { return }
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                store.setGroupingMode(mode)
            }
        }
    }

    private var groupingSelectionIndicator: some View {
        GeometryReader { geo in
            let width = geo.size.width / 2
            let baseOffset = store.groupingMode == .location ? 2.0 : width + 2.0
            let finalOffset = isDraggingGrouping ? 
                min(max(2, groupingDragOffset - (width/2)), width*2 - width + 2) : 
                baseOffset
            
            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                .frame(width: width - 4)
                .offset(x: finalOffset)
        }
    }

    private var groupingDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDraggingGrouping {
                    isDraggingGrouping = true
                }
                groupingDragOffset = value.location.x
                
                let midPoint = 70.0 // Half of 140
                if value.location.x < midPoint && store.groupingMode == .time {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        store.setGroupingMode(.location)
                    }
                } else if value.location.x > midPoint && store.groupingMode == .location {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        store.setGroupingMode(.time)
                    }
                }
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isDraggingGrouping = false
                }
            }
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = store.userName
        switch hour {
        case 0..<6: return "凌晨好，\(name)"
        case 6..<12: return "早上好，\(name)"
        case 12..<18: return "下午好，\(name)"
        default: return "晚上好，\(name)"
        }
    }
    
    private var uniqueLocationsCount: Int {
        Set(store.magnets.map { $0.location }).count
    }
    
    private func triggerRippleEffect() {
        rippleScale = 1.0
        rippleOpacity = 0.8
        
        withAnimation(.easeOut(duration: 0.8)) {
            rippleScale = 3.5
            rippleOpacity = 0.0
        }
    }
    
    private func triggerBackgroundRipple(at location: CGPoint) {
        bgRippleLocation = location
        bgRippleScale = 1.0
        bgRippleOpacity = 0.6
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred(intensity: 0.4)
        
        withAnimation(.easeOut(duration: 1.0)) {
            bgRippleScale = 6.0
            bgRippleOpacity = 0.0
        }
    }
}

struct GroupCard: View {
    let group: MagnetGroup
    let groupingMode: GroupingMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) { // Increased from 20 to 24
            // Header
            HStack(alignment: .center, spacing: 12) {
                // Color Indicator - more elegant pill shape
                Capsule()
                    .fill(group.color.opacity(0.8))
                    .frame(width: 4, height: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .font(Font.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(group.subtitle)
                        .font(Font.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                Spacer()
                
                // Count Badge - more subtle
                HStack(spacing: 4) {
                    Text("\(group.items.count)")
                        .font(Font.system(size: 12, weight: .bold, design: .monospaced))
                    Text("ITEMS")
                        .font(Font.system(size: 7, weight: .black))
                }
                .foregroundColor(.secondary.opacity(0.5))
                
                Image(systemName: "chevron.right")
                    .font(Font.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.2))
            }
            .padding(.horizontal, 4)
            
            // Item Previews - more spacing between items
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) { // Increased from 14 to 16
                    ForEach(group.items.prefix(6)) { item in
                        ItemPreview(item: item)
                    }
                    
                    if group.items.count > 6 {
                        MoreItemsView(count: group.items.count - 6)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 36)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 36)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}

struct ItemPreview: View {
    let item: MagnetItem
    
    var body: some View {
        ZStack {
            if let gifPath = item.gifPath {
                NativeGIFView(url: ImageManager.shared.getFileURL(for: gifPath))
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            } else if let image = ImageManager.shared.loadImage(filename: item.imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            }
        }
    }
}

struct MoreItemsView: View {
    let count: Int
    
    var body: some View {
        VStack(spacing: 2) {
            Text("+\(count)")
                .font(Font.system(size: 16, weight: .bold, design: .rounded))
            Text("MORE")
                .font(Font.system(size: 7, weight: .black))
        }
        .foregroundColor(.secondary.opacity(0.4))
        .frame(width: 80, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.black.opacity(0.02))
        )
    }
}

#Preview {
    HomeView(selectedTab: .constant(.home))
        .environmentObject(MagnetStore())
}
