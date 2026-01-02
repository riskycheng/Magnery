import SwiftUI

struct CommunityView: View {
    @EnvironmentObject var store: MagnetStore
    @StateObject private var communityService = CommunityService()
    @State private var isContentVisible = false
    @State private var selectedMagnet: MagnetItem?
    @State private var scrollOffset: CGFloat = 0
    @State private var initialOffset: CGFloat? = nil
    @State private var isCollapsed = false
    @State private var lastScrollUpdate: CGFloat = 0
    private let scrollUpdateThreshold: CGFloat = 1
    
    var body: some View {
        NavigationStack {
            GeometryReader { outerGeo in
                ZStack(alignment: .top) {
                    Color(red: 0.95, green: 0.95, blue: 0.97)
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Spacer for the fixed header - further reduced
                            Color.clear.frame(height: 90)
                            
                            if isContentVisible {
                                if let error = communityService.errorMessage {
                                    errorState(error)
                                        .padding(.top, 10)
                                } else {
                                    contentGrid
                                        .padding(.top, 5)
                                }
                            }
                        }
                        .background(
                            GeometryReader { geo in
                                let offset = geo.frame(in: .global).minY - outerGeo.frame(in: .global).minY
                                Color.clear
                                    .onChange(of: offset) { newValue in
                                        if initialOffset == nil {
                                            initialOffset = newValue
                                        }
                                        let calibratedOffset = newValue - (initialOffset ?? newValue)
                                        handleScroll(calibratedOffset)
                                    }
                            }
                        )
                    }
                    .opacity(isContentVisible ? 1 : 0)
                    .refreshable {
                        communityService.fetchCommunityContent()
                    }
                    
                    // Fixed Header Layer
                    headerLayer
                        .zIndex(1)
                    
                    // Central loading indicator for the very first fetch
                    if communityService.isLoading && communityService.popularMagnets.isEmpty {
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("正在探索社区...")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(red: 0.95, green: 0.95, blue: 0.97).opacity(0.8))
                        .transition(.opacity)
                    }
                }
            }
            .setTabBarVisibility(true)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedMagnet) { magnet in
                DetailView(magnet: magnet)
            }
            .onAppear {
                // 1. First, make the container visible
                withAnimation(.easeOut(duration: 0.3)) {
                    isContentVisible = true
                }
                
                // 2. Trigger the fetch immediately
                print("📱 [CommunityView] onAppear triggered")
                if communityService.popularMagnets.isEmpty {
                    print("📱 [CommunityView] Starting fetch because magnets are empty")
                    communityService.fetchCommunityContent()
                }
            }
        }
    }
    
    private var headerLayer: some View {
        let rawProgress = 1.0 + (scrollOffset / 100.0)
        let progress = min(1.0, max(0.0, rawProgress))
        let isDocked = scrollOffset < -60
        
        let titleSize = 18.0 + (16.0 * progress)
        let verticalSpacing = 2.0 + (4.0 * progress)
        
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: verticalSpacing) {
                    ZStack {
                        // Expanded Title (Leading)
                        HStack(alignment: .center, spacing: 8) {
                            Text("社区精选")
                                .font(Font.system(size: titleSize, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            if communityService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(Double(progress > 0.5 ? (progress - 0.5) * 2 : 0))
                        .offset(x: (1.0 - progress) * 20)
                        
                        // Docked Title (Center)
                        HStack(alignment: .center, spacing: 8) {
                            Text("社区精选")
                                .font(Font.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            if communityService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .opacity(Double(progress < 0.5 ? (0.5 - progress) * 2 : 0))
                        .offset(x: progress * -20)
                    }
                    
                    ZStack {
                        // Expanded Subtitle
                        Text("探索来自全球收藏家的精致冰箱贴")
                            .font(Font.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .opacity(Double(progress > 0.5 ? (progress - 0.5) * 2 : 0))
                        
                        // Docked Subtitle
                        Text("社区精选")
                            .font(Font.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .opacity(Double(progress < 0.5 ? (0.5 - progress) * 2 : 0))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 44) + (6.0 * progress))
            .padding(.bottom, 8.0 + (2.0 * progress))
            .background(
                ZStack {
                    if isDocked {
                        BlurView(style: .systemUltraThinMaterialLight)
                            .ignoresSafeArea()
                    } else {
                        Color(red: 0.95, green: 0.95, blue: 0.97)
                            .ignoresSafeArea()
                    }
                }
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
    
    private var contentGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 20) {
            if communityService.popularMagnets.isEmpty && communityService.isLoading {
                // Initial loading state: Show 6 skeletons
                ForEach(0..<6, id: \.self) { index in
                    skeletonCard
                        .transition(.opacity)
                }
            } else {
                // Content state: Show real cards
                ForEach(communityService.popularMagnets) { magnet in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedMagnet = magnet.toMagnetItem()
                        }
                    } label: {
                        communityCard(magnet: magnet)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity
                    ))
                }
                
                // If we are still loading more items
                if communityService.isLoading {
                    ForEach(0..<2, id: \.self) { _ in
                        skeletonCard
                            .pulsing()
                    }
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: communityService.popularMagnets.count)
        .padding(.horizontal)
        .padding(.bottom, 120)
    }
    
    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image Placeholder with layered animation
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.gray.opacity(0.15))
                
                // High-end glass shimmer
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .white.opacity(0.6), .clear]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shimmering()
            }
            .frame(height: 180)
            
            VStack(alignment: .leading, spacing: 8) {
                // Title Placeholder
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 120, height: 18)
                    .shimmering()
                
                // User Info Placeholder
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.gray.opacity(0.12))
                        .frame(width: 20, height: 20)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 60, height: 12)
                }
                .shimmering()
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.orange.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("网络连接较慢")
                    .font(.headline)
                Text("请检查网络设置或稍后重试")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                communityService.fetchCommunityContent()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("重新加载")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color.orange)
                .clipShape(Capsule())
                .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
    
    private func communityCard(magnet: CommunityMagnet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                // Persistent background to prevent layout shifts
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.gray.opacity(0.1))
                    .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
                
                Group {
                    // Always show the cover image in the list view
                    ZStack(alignment: .topTrailing) {
                        CachedAsyncImage(url: magnet.imageURL, fallbackURLs: magnet.imageFallbackURLs)
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                        
                        // Add badges for special types
                        if magnet.modelName != nil {
                            Image(systemName: "arkit")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.blue.opacity(0.8))
                                .clipShape(Circle())
                                .padding(8)
                        } else if magnet.gifName != nil {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                                .padding(8)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .frame(height: 180)
            
            // Fixed-height text container to prevent layout jumps
            VStack(alignment: .leading, spacing: 8) {
                Text(magnet.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(height: 18) // Match skeleton height exactly
                
                HStack {
                    Image(systemName: magnet.userAvatar)
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .frame(width: 20, height: 20) // Match skeleton circle exactly
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text(magnet.userName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(height: 12) // Match skeleton height exactly
                    
                    Spacer()
                    
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red.opacity(0.8))
                        Text("\(magnet.likes)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.05))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

#Preview {
    CommunityView()
        .environmentObject(MagnetStore())
}
