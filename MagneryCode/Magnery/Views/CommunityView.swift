import SwiftUI

struct CommunityView: View {
    @EnvironmentObject var store: MagnetStore
    @StateObject private var communityService = CommunityService()
    @State private var isContentVisible = false
    @State private var selectedMagnet: MagnetItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                if isContentVisible {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            headerSection
                            
                            if let error = communityService.errorMessage {
                                errorState(error)
                            } else {
                                contentGrid
                            }
                        }
                    }
                    .refreshable {
                        communityService.fetchCommunityContent()
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
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
                if communityService.popularMagnets.isEmpty {
                    print("📱 [CommunityView] Immediate fetch triggered")
                    communityService.fetchCommunityContent()
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("社区精选")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                
                if communityService.isLoading {
                    ProgressView()
                        .padding(.leading, 8)
                }
            }
            
            Text("探索来自全球收藏家的精致冰箱贴")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.top, 20)
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
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text(message)
                .foregroundColor(.secondary)
            Button("重试") {
                communityService.fetchCommunityContent()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
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
                    if let modelURL = magnet.modelURL {
                        ZStack(alignment: .topTrailing) {
                            // Show a 3D preview if possible, or just the image with a 3D badge
                            if let imageURL = magnet.imageURL {
                                CachedAsyncImage(url: imageURL)
                                    .aspectRatio(contentMode: .fill)
                            }
                            
                            Image(systemName: "arkit")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.blue.opacity(0.8))
                                .clipShape(Circle())
                                .padding(10)
                        }
                    } else if let gifURL = magnet.gifURL {
                        NativeGIFView(url: gifURL)
                    } else if let imageURL = magnet.imageURL {
                        CachedAsyncImage(url: imageURL)
                            .aspectRatio(contentMode: .fill)
                            .transition(.opacity.animation(.easeInOut(duration: 0.6)))
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
