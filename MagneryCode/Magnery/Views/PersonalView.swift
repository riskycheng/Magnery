import SwiftUI
import PhotosUI

struct PersonalView: View {
    @EnvironmentObject var store: MagnetStore
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var showingCropView = false
    @State private var showingNameAlert = false
    @State private var newName = ""
    @State private var showingCacheAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        
                        profileSection
                        
                        statsSection
                        
                        settingsSection
                        
                        Divider()
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                            .opacity(0.3)
                        
                        footerSection
                        
                        Spacer(minLength: 120) // Increased to ensure visibility above tab bar
                    }
                }
            }
            .setTabBarVisibility(true)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedItem) { newItem in
                guard let newItem = newItem else { return }
                Task {
                    do {
                        if let data = try await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                selectedImage = image
                                showingCropView = true
                                // Reset selection so it can be triggered again
                                selectedItem = nil
                            }
                        } else {
                            print("Failed to load image data")
                            await MainActor.run { selectedItem = nil }
                        }
                    } catch {
                        print("Error loading image: \(error)")
                        await MainActor.run { selectedItem = nil }
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCropView) {
                if let image = selectedImage {
                    CropView(originalImage: image, isAvatarMode: true) { croppedImage in
                        saveAvatar(croppedImage)
                    }
                }
            }
            .alert("修改昵称", isPresented: $showingNameAlert) {
                TextField("请输入新昵称", text: $newName)
                Button("取消", role: .cancel) { }
                Button("确定") {
                    if !newName.isEmpty {
                        store.userName = newName
                        store.saveUserProfile()
                    }
                }
            } message: {
                Text("好的昵称能让大家更容易记住你")
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("个人中心")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            
            Text("管理您的收藏与个人资料")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    private var profileSection: some View {
        HStack(spacing: 20) {
            // Avatar
            PhotosPicker(selection: $selectedItem, matching: .images) {
                ZStack {
                    if let avatarPath = store.userAvatarPath,
                       let image = ImageManager.shared.loadImage(filename: avatarPath) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                        .offset(x: 35, y: 35)
                )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Button(action: {
                    newName = store.userName
                    showingNameAlert = true
                }) {
                    HStack {
                        Text(store.userName)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                
                Text("ID: \(abs(store.userName.hashValue % 1000000))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            NavigationLink(destination: ListView()) {
                statCard(title: "已收藏", value: "\(store.magnets.count)", unit: "个", icon: "square.grid.2x2.fill", color: .orange)
            }
            
            NavigationLink(destination: MapView()) {
                statCard(title: "已点亮", value: "\(uniqueLocationsCount)", unit: "城", icon: "mappin.and.ellipse", color: .blue)
            }
        }
        .padding(.horizontal)
    }
    
    private func statCard(title: String, value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray.opacity(0.3))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(unit)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section 1: Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("设置")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .padding(.horizontal)
                
                VStack(spacing: 1) {
                    NavigationLink(destination: SettingsDetailView(title: "系统语言")) {
                        settingsRow(icon: "globe", title: "系统语言", color: .blue, value: store.systemLanguage)
                    }
                    Divider().padding(.leading, 60)
                    
                    Button(action: {
                        showingCacheAlert = true
                    }) {
                        settingsRow(icon: "trash.fill", title: "清理缓存", color: .red)
                    }
                    Divider().padding(.leading, 60)
                    
                    NavigationLink(destination: SettingsDetailView(title: "大模型选择")) {
                        settingsRow(icon: "cpu.fill", title: "大模型选择", color: .purple)
                    }
                }
                .background(Color.white)
                .cornerRadius(20)
                .padding(.horizontal)
                .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
            }
            
            // Section 2: About Us
            VStack(alignment: .leading, spacing: 12) {
                Text("关于我们")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .padding(.horizontal)
                
                VStack(spacing: 1) {
                    NavigationLink(destination: SettingsDetailView(title: "隐私政策")) {
                        settingsRow(icon: "hand.raised.fill", title: "隐私政策", color: .green)
                    }
                    Divider().padding(.leading, 60)
                    
                    NavigationLink(destination: SettingsDetailView(title: "服务条款")) {
                        settingsRow(icon: "doc.text.fill", title: "服务条款", color: .cyan)
                    }
                    Divider().padding(.leading, 60)
                    
                    NavigationLink(destination: SettingsDetailView(title: "常见问题")) {
                        settingsRow(icon: "questionmark.circle.fill", title: "常见问题", color: .orange)
                    }
                    Divider().padding(.leading, 60)
                    
                    NavigationLink(destination: SettingsDetailView(title: "关于 Magnery")) {
                        settingsRow(icon: "info.circle.fill", title: "关于 Magnery", color: .gray)
                    }
                    Divider().padding(.leading, 60)
                    
                    NavigationLink(destination: SettingsDetailView(title: "意见反馈")) {
                        settingsRow(icon: "envelope.fill", title: "意见反馈", color: .indigo)
                    }
                }
                .background(Color.white)
                .cornerRadius(20)
                .padding(.horizontal)
                .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
            }
        }
        .alert("清理缓存", isPresented: $showingCacheAlert) {
            Button("取消", role: .cancel) { }
            Button("清理", role: .destructive) {
                // Implement cache clearing logic here if needed
            }
        } message: {
            Text("确定要清理应用缓存吗？这将释放存储空间。")
        }
    }
    
    private var footerSection: some View {
        VStack(spacing: 20) {
            // App Logo
            if let icon = UIImage(named: "AppIcon") ?? UIImage(named: "AppLogo") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .cornerRadius(20)
            } else {
                // Fallback to a castle-like icon if AppIcon isn't available
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.1))
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: "fort.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.primary.opacity(0.6))
                }
                .frame(width: 80, height: 80)
            }
            
            VStack(spacing: 8) {
                VStack(spacing: 4) {
                    Text("Enjoy collections in")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    Text("Mangery")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.9))
                }
                
                Text("Copyright @2026 Magnery")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 40)
        .padding(.bottom, 20)
    }
    
    private func settingsRow(icon: String, title: String, color: Color, value: String? = nil) -> some View {
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
                .foregroundColor(.primary)
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    private var uniqueLocationsCount: Int {
        Set(store.magnets.map { $0.location }).count
    }
    
    private func saveAvatar(_ image: UIImage) {
        if let path = ImageManager.shared.saveImage(image) {
            store.userAvatarPath = path
            store.saveUserProfile()
        }
    }
}

#Preview {
    PersonalView()
        .environmentObject(MagnetStore())
}
