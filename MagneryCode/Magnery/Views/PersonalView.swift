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
    @State private var scrollOffset: CGFloat = 0
    @State private var initialOffset: CGFloat? = nil
    @State private var isCollapsed = false
    @State private var lastScrollUpdate: CGFloat = 0
    private let scrollUpdateThreshold: CGFloat = 1 // Reduced threshold for smoother tracking
    
    var body: some View {
        NavigationStack {
            GeometryReader { outerGeo in
                ZStack(alignment: .top) {
                    Color(red: 0.95, green: 0.95, blue: 0.97)
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Spacer for the fixed header
                            Color.clear.frame(height: 90)
                            
                            profileSection
                                .padding(.top, 10)
                            
                            statsSection
                                .padding(.top, 24)
                            
                            settingsSection
                                .padding(.top, 24)
                            
                            Divider()
                                .padding(.horizontal, 40)
                                .padding(.top, 20)
                                .opacity(0.3)
                            
                            footerSection
                                .padding(.top, 24)
                            
                            Spacer(minLength: 80)
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
                    
                    // Fixed Header Layer
                    headerLayer
                        .zIndex(1)
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
                            await MainActor.run { selectedItem = nil }
                        }
                    } catch {
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
    
    private var headerLayer: some View {
        let rawProgress = 1.0 + (scrollOffset / 100.0)
        let progress = min(1.0, max(0.0, rawProgress))
        let isDocked = scrollOffset < -60
        
        // Debug print for UI state
        // print("🎨 [Header] Progress: \(progress), Offset: \(scrollOffset)")
        
        let titleSize = 18.0 + (16.0 * progress)
        let verticalSpacing = 2.0 + (6.0 * progress)
        
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: verticalSpacing) {
                    ZStack {
                        // Expanded Title (Leading)
                        Text("个人中心")
                            .font(Font.system(size: titleSize, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .opacity(Double(progress > 0.5 ? (progress - 0.5) * 2 : 0))
                            .offset(x: (1.0 - progress) * 20)
                        
                        // Docked Title (Center)
                        Text("个人中心")
                            .font(Font.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .opacity(Double(progress < 0.5 ? (0.5 - progress) * 2 : 0))
                            .offset(x: progress * -20)
                    }
                    
                    ZStack {
                        // Expanded Subtitle
                        Text("管理您的收藏与个人资料")
                            .font(Font.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .opacity(Double(progress > 0.5 ? (progress - 0.5) * 2 : 0))
                        
                        // Docked Subtitle
                        Text("个人中心")
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
        .animation(.easeInOut(duration: 0.2), value: isDocked) // Add animation to the header itself
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
        HStack(spacing: 15) {
            NavigationLink(destination: ListView()) {
                modernStatCard(
                    title: "已收藏",
                    value: "\(store.magnets.count)",
                    unit: "个",
                    icon: "archivebox.fill",
                    colors: [.orange, .yellow]
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            NavigationLink(destination: MapView()) {
                modernStatCard(
                    title: "已点亮",
                    value: "\(uniqueLocationsCount)",
                    unit: "城",
                    icon: "map.fill",
                    colors: [.blue, .cyan]
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            NavigationLink(destination: QuotaShopView()) {
                modernStatCard(
                    title: "3D额度",
                    value: "\(store.threeDQuota)",
                    unit: "次",
                    icon: "cube.fill",
                    colors: [.purple, .indigo]
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
    }
    
    private func modernStatCard(title: String, value: String, unit: String, icon: String, colors: [Color]) -> some View {
        VStack(spacing: 12) {
            // Icon with Gradient Background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: colors.map { $0.opacity(0.15) }),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: colors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.top, 4)
            
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(unit)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
                
                // Subtle corner accent
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(colors[0].opacity(0.05))
                            .frame(width: 40, height: 40)
                            .offset(x: 10, y: -10)
                    }
                    Spacer()
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.03), lineWidth: 0.5)
        )
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section 1: Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("设置")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .padding(.horizontal)
                
                VStack(spacing: 1) {
                    NavigationLink(destination: ListView(isFavoritesOnly: true)) {
                        settingsRow(icon: "heart.fill", title: "特别收藏", color: .red)
                    }
                    Divider().padding(.leading, 60)
                    
                    Button(action: {
                        showingCacheAlert = true
                    }) {
                        settingsRow(icon: "trash.fill", title: "清理缓存", color: .red)
                    }
                }
                .background(Color.white)
                .cornerRadius(20)
                .padding(.horizontal)
                .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
            }
            
            // Section: AI Model Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("AI 模型选择")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .padding(.horizontal)
                
                VStack(spacing: 1) {
                    ForEach(AIModelType.allCases, id: \.self) { model in
                        Button(action: {
                            withAnimation {
                                store.aiModel = model
                                store.saveSettings()
                            }
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: store.aiModel == model ? "cpu.fill" : "cpu")
                                    .font(.system(size: 20))
                                    .foregroundColor(store.aiModel == model ? .purple : .gray)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.rawValue)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text(model.description)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if store.aiModel == model {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.purple)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        
                        if model != AIModelType.allCases.last {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(20)
                .padding(.horizontal)
                .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
            }
            
            // Section: 3D Reconstruction Mode
            VStack(alignment: .leading, spacing: 12) {
                Text("3D 重建设置")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .padding(.horizontal)
                
                VStack(spacing: 1) {
                    ForEach(ThreeDMode.allCases, id: \.self) { mode in
                        Button(action: {
                            withAnimation {
                                store.threeDMode = mode
                                store.saveSettings()
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.rawValue)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text(mode == .rapid ? "速度较快，生成效率高 (约 20-30s)" : "细节更丰富，专业级建模 (约 40-60s)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if store.threeDMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.purple)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white)
                        }
                        
                        if mode != ThreeDMode.allCases.last {
                            Divider().padding(.leading, 16)
                        }
                    }
                    
                    Divider().padding(.leading, 16)
                    
                    // Top-up Button Entry
                    NavigationLink(destination: QuotaShopView()) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(gradient: Gradient(colors: [.orange, .yellow]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 38, height: 38)
                                    .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)
                                
                                Image(systemName: "sparkles.tv.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18))
                            }
                            .padding(.leading, 16)
                            
                            Text("获取更多额度")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.trailing, 16)
                        }
                        .padding(.vertical, 14)
                        .background(Color.white)
                    }
                    .buttonStyle(PlainButtonStyle())
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
                clearAppCache()
            }
        } message: {
            Text("确定要清理应用缓存吗？这将删除从社区下载的所有图片和模型。")
        }
    }
    
    private func clearAppCache() {
        let fileManager = FileManager.default
        
        // 1. Clear ImageCache in Caches directory
        if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let imageCacheURL = cachesURL.appendingPathComponent("ImageCache")
            try? fileManager.removeItem(at: imageCacheURL)
        }
        
        // 2. Clear manifest cache if any (CommunityService might use this)
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let manifestURL = documentsURL.appendingPathComponent("community_manifest.json")
            try? fileManager.removeItem(at: manifestURL)
            
            // Also clear any other community related cached JSONs
            let contents = try? fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            contents?.forEach { url in
                if url.lastPathComponent.hasPrefix("community_") && url.pathExtension == "json" {
                    try? fileManager.removeItem(at: url)
                }
            }
        }
        
        // 3. Clear temporary directory
        let tempDir = fileManager.temporaryDirectory
        if let tempContents = try? fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            tempContents.forEach { try? fileManager.removeItem(at: $0) }
        }
    }
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            VStack(spacing: 4) {
                Text("Enjoy collections in")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.8))
                
                Text("Magnery")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.9))
            }
            
            Text("Copyright @2026 Magnery")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 30)
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
