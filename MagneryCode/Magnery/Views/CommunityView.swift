import SwiftUI

struct CommunityView: View {
    @EnvironmentObject var store: MagnetStore
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("社区精选")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .padding(.horizontal)
                            .padding(.top, 20)
                        
                        Text("探索来自全球收藏家的精致冰箱贴")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        // Placeholder for community content
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(0..<10) { i in
                                communityCard(index: i)
                            }
                        }
                        .padding()
                        .padding(.bottom, 100) // Space for floating tab bar
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func communityCard(index: Int) -> some View {
        VStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .frame(height: 180)
                .overlay(
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.3))
                )
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            
            Text("精选冰箱贴 #\(index + 1)")
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 8)
            
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 20, height: 20)
                Text("收藏家 \(index + 1)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Spacer()
                Image(systemName: "heart")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.top, 2)
        }
    }
}

#Preview {
    CommunityView()
        .environmentObject(MagnetStore())
}
