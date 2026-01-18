import SwiftUI

struct QuotaShopView: View {
    @EnvironmentObject var store: MagnetStore
    @Environment(\.dismiss) var dismiss
    
    let packages = [
        QuotaPackage(id: "quota_small", name: "基础包", quota: 4, price: "¥6.00", icon: "sparkles", color: .blue),
        QuotaPackage(id: "quota_medium", name: "超值包", quota: 10, price: "¥12.00", icon: "sparkles.rectangle.stack", color: .purple, isPopular: true),
        QuotaPackage(id: "quota_large", name: "专业包", quota: 20, price: "¥25.00", icon: "crown.fill", color: .orange)
    ]
    
    @State private var showingCustomAmountAlert = false
    @State private var customAmount = ""
    
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
                    
                    Text("当前剩余额度: \(store.threeDQuota) 积分")
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
                    
                    customAmountRow
                }
                .padding(.horizontal)
                
                // Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("关于积分")
                        .font(.headline)
                    
                    bulletPoint("专业版 3D 重建消耗 2 个积分，极速版消耗 1 个积分。")
                    bulletPoint("新用户首次登录将获得 10 个初始积分。")
                    bulletPoint("购买后的积分永久有效，不设过期时间。")
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
        .alert("任意积分购买", isPresented: $showingCustomAmountAlert) {
            TextField("输入要购买的积分数量", text: $customAmount)
                .keyboardType(.numberPad)
            Button("取消", role: .cancel) { }
            Button("准备购买") {
                if let amount = Int(customAmount) {
                    // In real app, trigger payment
                    // For now, it's "Coming Soon" behavior too or just mock
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }
            }
        } message: {
            Text("请输入您想要购买的积分数量。")
        }
    }
    
    private var customAmountRow: some View {
        Button(action: {
            // showingCustomAmountAlert = true
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("自定义数量")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("输入您需要的任意积分数")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("即将到来")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(20)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func packageRow(_ package: QuotaPackage) -> some View {
        Button(action: {
            // No action as it's "Coming Soon"
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
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
                    
                    Text("\(package.quota) 个 3D 重建积分")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("即将到来")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
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
