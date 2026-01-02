import SwiftUI

enum Tab: String, CaseIterable {
    case home = "house.fill"
    case community = "globe.asia.australia.fill"
    case personal = "person.fill"
    
    var title: String {
        switch self {
        case .home: return "首页"
        case .community: return "社区"
        case .personal: return "个人"
        }
    }
    
    var index: Int {
        switch self {
        case .home: return 0
        case .community: return 1
        case .personal: return 2
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @State private var dragOffset: CGFloat? = nil
    @State private var hoverTab: Tab? = nil
    @State private var isTabBarVisible: Bool = true
    @EnvironmentObject var store: MagnetStore
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content with Custom Switcher (No full-screen swipe)
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    HomeView(selectedTab: $selectedTab)
                        .frame(width: proxy.size.width)
                        .transformPreference(TabBarVisibilityPreferenceKey.self) { value in
                            if selectedTab != .home { value = true }
                        }
                        .allowsHitTesting(selectedTab == .home)
                    
                    CommunityView()
                        .frame(width: proxy.size.width)
                        .transformPreference(TabBarVisibilityPreferenceKey.self) { value in
                            if selectedTab != .community { value = true }
                        }
                        .allowsHitTesting(selectedTab == .community)
                    
                    PersonalView()
                        .frame(width: proxy.size.width)
                        .transformPreference(TabBarVisibilityPreferenceKey.self) { value in
                            if selectedTab != .personal { value = true }
                        }
                        .allowsHitTesting(selectedTab == .personal)
                }
                .offset(x: -CGFloat(selectedTab.index) * proxy.size.width)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
            .ignoresSafeArea()
            
            // Floating Tab Bar
            if isTabBarVisible {
                floatingTabBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.97).ignoresSafeArea())
        .onPreferenceChange(TabBarVisibilityPreferenceKey.self) { visible in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isTabBarVisible = visible
            }
        }
    }
    
    private var floatingTabBar: some View {
        GeometryReader { geometry in
            let barWidth = geometry.size.width - 60
            let barHeight: CGFloat = 72
            let tabWidth = barWidth / CGFloat(Tab.allCases.count)
            
            ZStack(alignment: .leading) {
                // Background Capsule
                Capsule()
                    .fill(Color.white.opacity(0.98))
                    .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
                
                // Liquid Selection Indicator
                Canvas { context, size in
                    guard size.width > 0 && size.height > 0 else { return }
                    
                    context.addFilter(.blur(radius: 15))
                    context.addFilter(.alphaThreshold(min: 0.5, color: Color.black.opacity(0.18)))
                    
                    context.drawLayer { ctx in
                        let currentX = CGFloat(selectedTab.index) * tabWidth + (tabWidth / 2)
                        
                        if let dragX = dragOffset {
                            let dragCenter = dragX + (tabWidth / 2)
                            
                            // Base bubble (stays at current tab but stretches)
                            let baseSize: CGFloat = 62
                            let baseRect = CGRect(x: currentX - baseSize/2, y: size.height / 2 - baseSize/2, width: baseSize, height: baseSize)
                            ctx.fill(Path(ellipseIn: baseRect), with: .color(.black))
                            
                            // Drag bubble (follows finger)
                            let dragSize: CGFloat = 72
                            let dragRect = CGRect(x: dragCenter - dragSize/2, y: size.height / 2 - dragSize/2, width: dragSize, height: dragSize)
                            ctx.fill(Path(ellipseIn: dragRect), with: .color(.black))
                            
                            // Optional: Add a small connecting circle in the middle for better liquid bridge
                            let midX = (currentX + dragCenter) / 2
                            let midSize: CGFloat = 48
                            let midRect = CGRect(x: midX - midSize/2, y: size.height / 2 - midSize/2, width: midSize, height: midSize)
                            ctx.fill(Path(ellipseIn: midRect), with: .color(.black))
                        } else {
                            let baseSize: CGFloat = 68
                            let baseRect = CGRect(x: currentX - baseSize/2, y: size.height / 2 - baseSize/2, width: baseSize, height: baseSize)
                            ctx.fill(Path(ellipseIn: baseRect), with: .color(.black))
                        }
                    }
                }
                .frame(width: barWidth, height: barHeight)
                .clipShape(Capsule()) // Ensure liquid effect doesn't exceed rounded corners
                .drawingGroup() // Offload complex liquid filters to GPU
                
                // Tab Buttons
                HStack(spacing: 0) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        tabButton(tab: tab, width: tabWidth, height: barHeight)
                    }
                }
            }
            .frame(width: barWidth, height: barHeight)
            .position(x: geometry.size.width / 2, y: geometry.size.height - 30) // Even lower
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = value.location.x - (tabWidth / 2)
                        let clampedX = max(0, min(barWidth - tabWidth, x))
                        
                        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8)) {
                            dragOffset = clampedX
                        }
                        
                        // Update hover state for icon feedback
                        let index = Int((value.location.x / tabWidth).rounded(.down))
                        let safeIndex = max(0, min(Tab.allCases.count - 1, index))
                        let newHoverTab = Tab.allCases[safeIndex]
                        
                        if newHoverTab != hoverTab {
                            hoverTab = newHoverTab
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        }
                    }
                    .onEnded { value in
                        let index = Int((value.location.x / tabWidth).rounded(.down))
                        let safeIndex = max(0, min(Tab.allCases.count - 1, index))
                        let finalTab = Tab.allCases[safeIndex]
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedTab = finalTab
                            dragOffset = nil
                            hoverTab = nil
                        }
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    }
            )
        }
        .frame(height: 80)
        .padding(.horizontal, 30)
    }
    
    private func tabButton(tab: Tab, width: CGFloat, height: CGFloat) -> some View {
        let isHighlighted = (hoverTab ?? selectedTab) == tab
        
        return VStack(spacing: 4) {
            Image(systemName: tab.rawValue)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(isHighlighted ? .orange : .black.opacity(0.4))
                .scaleEffect(isHighlighted ? 1.25 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHighlighted)
            
            Text(tab.title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(isHighlighted ? .orange : .black.opacity(0.4))
                .scaleEffect(isHighlighted ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHighlighted)
        }
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selectedTab = tab
            }
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(MagnetStore())
}
