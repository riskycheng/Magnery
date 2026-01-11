import SwiftUI

struct QuotaShopView: View {
    @EnvironmentObject var store: MagnetStore
    @Environment(\.dismiss) var dismiss
    
    let packages = [
        QuotaPackage(id: "quota_small", name: "基础包", quota: 10, price: "¥6.00", icon: "sparkles", color: .blue),
        QuotaPackage(id: "quota_medium", name: "超值包", quota: 30, price: "¥12.00", icon: "sparkles.rectangle.stack", color: .purple, isPopular: true),
        QuotaPackage(id: "quota_large", name: "专业包", quota: 100, price: "¥30.00", icon: "crown.fill", color: .orange)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 80, height: 80)
                        Image(systemName: "cube.transparent.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.purple)
                    }
                    
                    Text("获取 3D 重建额度")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    
                    Text("当前剩余额度: \(store.threeDQuota) 次")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.top, 40)
                
                // Packages
                VStack(spacing: 16) {
                    ForEach(packages) { package in
                        packageRow(package)
                    }
                }
                .padding(.horizontal)
                
                // Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("关于额度")
                        .font(.headline)
                    
                    bulletPoint("专业版 3D 重建消耗 1 个额度，极速版不消耗额度（Beta 期间临时策略）。")
                    bulletPoint("购买后的额度永久有效，不设过期时间。")
                    bulletPoint("由于 3D 生成需要消耗大量云端算力，建议在光线充足、背景简单的环境下拍摄以获得最佳效果。")
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(16)
                .padding(.horizontal)
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("商店")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func packageRow(_ package: QuotaPackage) -> some View {
        Button(action: {
            // Mock purchase
            store.threeDQuota += package.quota
            store.saveQuota()
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(package.color.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: package.icon)
                        .font(.system(size: 24))
                        .foregroundColor(package.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(package.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        if package.isPopular {
                            Text("最受欢迎")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("\(package.quota) 次 3D 重建额度")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(package.price)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(package.color)
                    .cornerRadius(20)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.purple)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}

struct QuotaPackage: Identifiable {
    let id: String
    let name: String
    let quota: Int
    let price: String
    let icon: String
    let color: Color
    var isPopular: Bool = false
}
