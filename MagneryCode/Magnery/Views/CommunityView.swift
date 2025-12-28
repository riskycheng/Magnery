import SwiftUI

struct CommunityView: View {
    @EnvironmentObject var store: MagnetStore
    @StateObject private var communityService = CommunityService()
    @State private var isContentVisible = false
    
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
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // 1. First, make the container visible with a slight delay to avoid transition stutter
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isContentVisible = true
                    }
                }
                
                // 2. Then, trigger the fetch after the content has started appearing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if communityService.popularMagnets.isEmpty {
                        print("📱 [CommunityView] Delayed fetch triggered")
                        communityService.fetchCommunityContent()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("社区精选")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            
            Text("探索来自全球收藏家的精致冰箱贴")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    private var contentGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            if communityService.isLoading && communityService.popularMagnets.isEmpty {
                // Show skeletons while loading the first batch
                ForEach(0..<6, id: \.self) { _ in
                    skeletonCard
                }
            } else {
                ForEach(communityService.popularMagnets) { magnet in
                    communityCard(magnet: magnet)
                }
                
                // If still loading more, show a few skeletons at the end
                if communityService.isLoading {
                    ForEach(0..<2, id: \.self) { _ in
                        skeletonCard
                    }
                }
            }
        }
        .padding()
        .padding(.bottom, 100)
    }
    
    private var skeletonCard: some View {
        VStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .frame(height: 180)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.2), Color.gray.opacity(0.1)]), startPoint: .leading, endPoint: .trailing))
                        .shimmering()
                )
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 100, height: 14)
                .padding(.top, 8)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 60, height: 10)
                .padding(.top, 4)
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
        VStack(alignment: .leading) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                
                if let gifURL = magnet.gifURL {
                    NativeGIFView(url: gifURL)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else if let imageURL = magnet.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.1))
                            .shimmering()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .frame(height: 180)
            
            Text(magnet.name)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .padding(.top, 8)
            
            HStack {
                Image(systemName: magnet.userAvatar)
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                Text(magnet.userName)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Spacer()
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    Text("\(magnet.likes)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 2)
        }
    }
}

#Preview {
    CommunityView()
        .environmentObject(MagnetStore())
}
