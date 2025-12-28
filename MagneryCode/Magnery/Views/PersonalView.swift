import SwiftUI

struct PersonalView: View {
    @EnvironmentObject var store: MagnetStore
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        VStack(spacing: 16) {
                            Circle()
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.orange)
                                )
                                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                            
                            VStack(spacing: 4) {
                                Text("收藏家")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                Text("已收藏 \(store.magnets.count) 个冰箱贴")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 40)
                        
                        // Settings Sections
                        VStack(spacing: 16) {
                            settingsRow(icon: "bell.fill", title: "通知设置", color: .blue)
                            settingsRow(icon: "shield.fill", title: "隐私与安全", color: .green)
                            settingsRow(icon: "cloud.fill", title: "云端备份", color: .cyan)
                            settingsRow(icon: "questionmark.circle.fill", title: "帮助与反馈", color: .orange)
                            settingsRow(icon: "info.circle.fill", title: "关于 Magnery", color: .gray)
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func settingsRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 18))
            }
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.02), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    PersonalView()
        .environmentObject(MagnetStore())
}
