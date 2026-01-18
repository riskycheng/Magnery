import SwiftUI
import Photos

struct EllipsisButtonBoundsKey: PreferenceKey {
    static var defaultValue: CGRect?
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = value ?? nextValue()
    }
}

struct DetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: MagnetStore
    @Environment(\.horizontalSizeClass) var sizeClass
    let magnet: MagnetItem
    @State private var showingAIDialog = false
    @State private var showingEditMenu = false
    @State private var showingEditSheet = false
    @State private var currentMagnet: MagnetItem
    @State private var groupItems: [MagnetItem] = []
    @State private var ellipsisButtonFrame: CGRect = .zero
    @State private var refreshTrigger: Bool = false
    @State private var showingDeleteConfirmation = false
    @State private var itemToShare: MagnetItem? = nil
    @State private var isCollecting = false
    @StateObject private var downloadManager = DownloadManager()
    
    private var isIPad: Bool {
        sizeClass == .regular
    }
    
    private var contentHeight: CGFloat {
        isIPad ? 580 : 380
    }
    
    // 3D Generation in Detail
    @State private var isGenerating3D = false
    @State private var conversionProgress: Double = 0
    @State private var statusMessage: String = ""
    @State private var showing3DQuotaAlert = false
    
    // View Mode Toggle
    enum ViewMode {
        case twoD
        case threeD
    }
    @State private var viewMode: ViewMode = .threeD
    
    private var isCommunityMagnet: Bool {
        currentMagnet.imagePath.hasPrefix("http")
    }
    
    private var isAlreadyCollected: Bool {
        store.magnets.contains(where: { $0.name == currentMagnet.name && $0.location == currentMagnet.location })
    }
    
    init(magnet: MagnetItem) {
        self.magnet = magnet
        _currentMagnet = State(initialValue: magnet)
        _viewMode = State(initialValue: magnet.modelPath != nil ? .threeD : .twoD)
    }
    
    var body: some View {
        GeometryReader { mainGeo in
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(groupTitle)
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if !groupItems.isEmpty {
                            itemsScrollView
                        }
                    }
                    .padding(.top, 8)
                
                Spacer()
                
                ZStack {
                    if viewMode == .threeD, let modelPath = currentMagnet.modelPath {
                        Model3DView(url: ImageManager.shared.getFileURL(for: modelPath))
                            .id(modelPath)
                            .frame(maxWidth: .infinity)
                            .frame(height: contentHeight)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                    } else if let gifPath = currentMagnet.gifPath {
                        NativeGIFView(url: ImageManager.shared.getFileURL(for: gifPath))
                            .id(gifPath)
                            .frame(maxHeight: contentHeight)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                            .gesture(
                                DragGesture(minimumDistance: 30)
                                    .onEnded { value in
                                        handleSwipeGesture(translation: value.translation)
                                    }
                            )
                    } else {
                        // Handle both local and remote images
                        Group {
                            if currentMagnet.imagePath.hasPrefix("http") {
                                CachedAsyncImage(url: currentMagnet.imageURL, fallbackURLs: currentMagnet.imageFallbackURLs)
                                    .aspectRatio(contentMode: .fit)
                            } else if let image = ImageManager.shared.loadImage(filename: currentMagnet.imagePath) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                        }
                        .id(currentMagnet.imagePath)
                        .frame(maxHeight: contentHeight)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                        .gesture(
                            DragGesture(minimumDistance: 30)
                                .onEnded { value in
                                        handleSwipeGesture(translation: value.translation)
                                }
                        )
                    }
                    
                    // View Mode Switcher Overlay
                    if currentMagnet.modelPath != nil {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                viewModeToggle
                                    .padding(.trailing, 30)
                                    .padding(.bottom, 10)
                            }
                        }
                    }
                }
                .frame(height: contentHeight)
                
                VStack(spacing: 8) {
                    Text(currentMagnet.name)
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                    
                    if !currentMagnet.notes.isEmpty {
                        Text(currentMagnet.notes)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    // Categories
                    if let l1 = currentMagnet.categoryLevel1 {
                        HStack(spacing: 8) {
                            categoryTag(l1, color: .blue)
                            if let l2 = currentMagnet.categoryLevel2 {
                                categoryTag(l2, color: .purple)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.top, 24)
                
                Spacer()
                
                Button(action: {
                    showingAIDialog = true
                }) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                        Text("AI科普")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Color.orange)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 40)
            }
            
            // Dimmed background when menu is showing
            if showingEditMenu {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showingEditMenu = false
                        }
                    }
            }
            
            if showingEditMenu && ellipsisButtonFrame != .zero {
                circularMenuButtons
                    .fixedSize()
                    .frame(width: 0, height: 0, alignment: .top)
                    .position(
                        x: ellipsisButtonFrame.midX - mainGeo.frame(in: .global).minX,
                        y: ellipsisButtonFrame.maxY - mainGeo.frame(in: .global).minY + 20
                    )
                    .zIndex(999)
            }
            
            if isCollecting {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 15) {
                        ProgressView(value: downloadManager.progress)
                            .progressViewStyle(.linear)
                            .frame(width: 150)
                            .tint(.white)
                        
                        Text("正在收藏到本地...")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(BlurView(style: .systemMaterialDark))
                    .cornerRadius(20)
                }
                .transition(.opacity)
                .zIndex(1000)
            }
        }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingEditMenu.toggle()
                    }
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(
                                        key: EllipsisButtonBoundsKey.self,
                                        value: geo.frame(in: .global).midX > 0 ? geo.frame(in: .global) : nil
                                    )
                            }
                        )
                }
            }
        }
        .onPreferenceChange(EllipsisButtonBoundsKey.self) { frame in
            if let frame = frame {
                ellipsisButtonFrame = frame
            }
        }
        .setTabBarVisibility(false)
        .onAppear {
            loadGroupItems()
        }
        .sheet(item: $itemToShare) { item in
            SharePreviewView(item: item)
        }
        .sheet(isPresented: $showingAIDialog) {
            AIDialogView(magnet: $currentMagnet)
        }
        .onChange(of: currentMagnet) { oldValue, newValue in
            // Default to 3D if available when switching items
            if newValue.modelPath != nil {
                viewMode = .threeD
            } else {
                viewMode = .twoD
            }
        }
        .onChange(of: showingAIDialog) { oldValue, newValue in
            if !newValue {
                // Refresh group items when AI dialog is closed to ensure cache is synced
                loadGroupItems()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditMagnetSheet(magnet: $currentMagnet, onSave: {
                store.updateMagnet(currentMagnet)
                showingEditSheet = false
            })
        }
        .alert("额度不足", isPresented: $showing3DQuotaAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("您的 3D 重建额度已用完，请在个人中心充值。")
        }
        .overlay {
            if isGenerating3D {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    ThreeDProgressView(progress: conversionProgress, status: statusMessage)
                }
                .transition(.opacity)
            }
        }
        .alert("确认删除", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteMagnet()
            }
        } message: {
            Text("确定要删除「\(currentMagnet.name)」吗？")
        }
    }
    
    private var itemsScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(groupItems) { item in
                        Button(action: {
                            withAnimation {
                                currentMagnet = item
                            }
                        }) {
                            Group {
                                if item.imagePath.hasPrefix("http") {
                                    AsyncImage(url: URL(string: item.imagePath)) { phase in
                                        if case .success(let image) = phase {
                                            image.resizable()
                                                .aspectRatio(contentMode: .fit)
                                        } else {
                                            Color.gray.opacity(0.1)
                                        }
                                    }
                                } else if let image = ImageManager.shared.loadImage(filename: item.imagePath) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                }
                            }
                            .frame(width: 60, height: 60)
                            .opacity(item.id == currentMagnet.id ? 1.0 : 0.5)
                            .scaleEffect(item.id == currentMagnet.id ? 1.3 : 0.9)
                            .shadow(
                                color: item.id == currentMagnet.id ? .blue.opacity(0.3) : .clear,
                                radius: item.id == currentMagnet.id ? 8 : 0,
                                x: 0,
                                y: 2
                            )
                        }
                        .id(item.id)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .frame(height: 100)
            .onChange(of: currentMagnet.id) { oldValue, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(currentMagnet.id, anchor: .center)
            }
        }
    }
    
    private func categoryTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
    
    private var circularMenuButtons: some View {
        let buttonSize: CGFloat = 50
        let spacing: CGFloat = 12
        
        return VStack(spacing: spacing) {
            // Share Button
            Button(action: {
                showingEditMenu = false
                itemToShare = currentMagnet
            }) {
                menuButtonOverlay(icon: "square.and.arrow.up.fill", color: .blue, size: buttonSize)
            }
            .transition(.scale.combined(with: .opacity))
            
            if isCommunityMagnet {
                if !isAlreadyCollected {
                    // Collect Button
                    Button(action: {
                        collectMagnet()
                    }) {
                        menuButtonOverlay(icon: "plus.circle.fill", color: .green, size: buttonSize)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            } else {
                if currentMagnet.modelPath == nil {
                    // Generate 3D Button
                    Button(action: {
                        showingEditMenu = false
                        start3DGeneration()
                    }) {
                        menuButtonOverlay(icon: "cube.transparent.fill", color: .purple, size: buttonSize)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Edit Button
                Button(action: {
                    showingEditMenu = false
                    showingEditSheet = true
                }) {
                    menuButtonOverlay(icon: "pencil.circle.fill", color: .orange, size: buttonSize)
                }
                .transition(.scale.combined(with: .opacity))
                
                // Delete Button
                Button(action: {
                    showingEditMenu = false
                    showingDeleteConfirmation = true
                }) {
                    menuButtonOverlay(icon: "trash.circle.fill", color: .red, size: buttonSize)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
        )
    }
    
    private func menuButtonOverlay(icon: String, color: Color, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: size, height: size)
            
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
        }
    }
    
    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    viewMode = .twoD
                }
            }) {
                Text("2D")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(viewMode == .twoD ? .white : .secondary)
                    .frame(width: 40, height: 26)
                    .background(viewMode == .twoD ? Color.blue : Color.clear)
                    .clipShape(Capsule())
            }
            
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    viewMode = .threeD
                }
            }) {
                Text("3D")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(viewMode == .threeD ? .white : .secondary)
                    .frame(width: 40, height: 26)
                    .background(viewMode == .threeD ? Color.purple : Color.clear)
                    .clipShape(Capsule())
            }
        }
        .padding(3)
        .background(BlurView(style: .systemUltraThinMaterial))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    private var groupTitle: String {
        if store.groupingMode == .location {
            return currentMagnet.location
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日"
            return formatter.string(from: currentMagnet.date)
        }
    }
    
    private func loadGroupItems() {
        let groups = store.groupedMagnets()
        if let group = groups.first(where: { group in
            group.items.contains(where: { $0.id == currentMagnet.id })
        }) {
            groupItems = group.items.sorted { $0.date > $1.date }
        } else {
            groupItems = []
        }
    }
    
    private func start3DGeneration() {
        guard !isGenerating3D else { return }
        
        // 1. Check Quota
        let cost = store.threeDMode == .pro ? 2 : 1
        guard store.threeDQuota >= cost else {
            showing3DQuotaAlert = true
            return
        }
        
        // 2. Get Image
        guard !currentMagnet.imagePath.hasPrefix("http"),
              let image = ImageManager.shared.loadImage(filename: currentMagnet.imagePath) else {
            // Cannot generate 3D for community magnets or missing images
            return
        }
        
        isGenerating3D = true
        statusMessage = "准备图像..."
        conversionProgress = 0.1
        
        Task {
            do {
                // 1. Prepare Base64
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw NSError(domain: "DetailView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to process image data"])
                }
                let base64 = imageData.base64EncodedString()
                
                // 2. Submit Job
                let useProMode = store.threeDMode == .pro
                await MainActor.run { 
                    statusMessage = "提交\(useProMode ? "专业版" : "极速版")任务..."
                    conversionProgress = 0.3
                }
                let jobId = try await Tencent3DService.shared.submitJob(imageBase64: base64, useProMode: useProMode)
                
                // 3. Poll Status
                await MainActor.run {
                    statusMessage = "AI 正在重建 3D 模型\n这可能需要 \(useProMode ? "50-60 秒" : "20-30 秒")"
                    conversionProgress = 0.4
                }
                
                // Start a background task to slowly increment progress so user doesn't think it's stuck
                let progressTask = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 2 * 1_000_000_000) // Every 2 seconds
                        await MainActor.run {
                            if conversionProgress < 0.9 {
                                withAnimation {
                                    conversionProgress += 0.01
                                }
                            }
                        }
                    }
                }
                
                var usdzUrlString = try await Tencent3DService.shared.pollJobStatus(jobId: jobId, useProMode: useProMode)
                progressTask.cancel()
                
                // 4. Finalize
                await MainActor.run {
                    statusMessage = "转换完成！"
                    conversionProgress = 1.0
                }
                
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                // Actually we should download the model to local storage to persist it
                if let url = URL(string: usdzUrlString) {
                    let tempURL = try await downloadManager.download(url: url, to: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".usdz"))
                    if let savedName = ImageManager.shared.saveFile(from: tempURL, extension: "usdz") {
                        usdzUrlString = savedName
                    }
                }
                
                await MainActor.run {
                    // Update the magnet in store
                    _ = store.useQuota(mode: store.threeDMode)
                    currentMagnet.modelPath = usdzUrlString
                    store.updateMagnet(currentMagnet)
                    isGenerating3D = false
                    
                    let impact = UINotificationFeedbackGenerator()
                    impact.notificationOccurred(.success)
                }
                
            } catch {
                print("❌ [DetailView] 3D Generation failed: \(error)")
                await MainActor.run {
                    isGenerating3D = false
                }
            }
        }
    }
    
    private func saveAsWallpaper() {
        guard let image = ImageManager.shared.loadImage(filename: currentMagnet.imagePath) else { return }
        
        // Save as PNG to preserve transparency if it's a sticker
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            if let data = image.pngData() {
                request.addResource(with: .photo, data: data, options: nil)
            }
        }) { success, error in
            if success {
                // Success
            } else {
                print("Error saving image: \(String(describing: error))")
            }
        }
    }
    
    private func handleSwipeGesture(translation: CGSize) {
        guard !groupItems.isEmpty else { return }
        
        let currentIndex = groupItems.firstIndex(where: { $0.id == currentMagnet.id }) ?? 0
        
        // 右滑 (translation.width > 0) -> 上一个item
        // 左滑 (translation.width < 0) -> 下一个item
        if translation.width > 0 {
            // 右滑：切换到上一个
            if currentIndex > 0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentMagnet = groupItems[currentIndex - 1]
                    refreshTrigger.toggle()
                }
            }
        } else if translation.width < 0 {
            // 左滑：切换到下一个
            if currentIndex < groupItems.count - 1 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentMagnet = groupItems[currentIndex + 1]
                    refreshTrigger.toggle()
                }
            }
        }
    }
    
    private func collectMagnet() {
        isCollecting = true
        showingEditMenu = false
        
        Task {
            var localMagnet = currentMagnet
            // Use a new UUID for the local copy to avoid conflicts
            let newId = UUID()
            
            // 1. Download and save image
            if let imageURL = currentMagnet.imageURL, currentMagnet.imagePath.hasPrefix("http") {
                do {
                    let tempURL = try await downloadManager.download(url: imageURL, to: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
                    if let data = try? Data(contentsOf: tempURL), let image = UIImage(data: data) {
                        if let savedName = ImageManager.shared.saveImage(image) {
                            localMagnet.imagePath = savedName
                        }
                    }
                } catch {
                    print("❌ [DetailView] Failed to download image: \(error.localizedDescription)")
                }
            }
            
            // 2. Download and save GIF if exists
            if let gifURL = currentMagnet.gifURL, currentMagnet.gifPath?.hasPrefix("http") == true {
                do {
                    let tempURL = try await downloadManager.download(url: gifURL, to: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
                    if let savedName = ImageManager.shared.saveFile(from: tempURL, extension: "gif") {
                        localMagnet.gifPath = savedName
                    }
                } catch {
                    print("❌ [DetailView] Failed to download GIF: \(error.localizedDescription)")
                }
            }
            
            // 3. Download and save 3D model if exists
            if let modelURL = currentMagnet.modelURL, currentMagnet.modelPath?.hasPrefix("http") == true {
                do {
                    let tempURL = try await downloadManager.download(url: modelURL, to: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
                    if let savedName = ImageManager.shared.saveFile(from: tempURL, extension: "usdz") {
                        localMagnet.modelPath = savedName
                    }
                } catch {
                    print("❌ [DetailView] Failed to download model: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                // Create the final local magnet with the new ID
                let finalMagnet = MagnetItem(
                    id: newId,
                    name: localMagnet.name,
                    date: Date(), // Use current date for collection
                    location: localMagnet.location,
                    latitude: localMagnet.latitude,
                    longitude: localMagnet.longitude,
                    imagePath: localMagnet.imagePath,
                    gifPath: localMagnet.gifPath,
                    modelPath: localMagnet.modelPath,
                    notes: localMagnet.notes,
                    categoryLevel1: localMagnet.categoryLevel1,
                    categoryLevel2: localMagnet.categoryLevel2
                )
                
                store.addMagnet(finalMagnet)
                isCollecting = false
                
                // Update current view to the local one
                withAnimation {
                    currentMagnet = finalMagnet
                }
                
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
        }
    }
    
    private func deleteMagnet() {
        let currentIndex = groupItems.firstIndex(where: { $0.id == currentMagnet.id })
        
        // 在删除前，从当前的groupItems中确定下一个要显示的item
        var nextMagnet: MagnetItem?
        if let index = currentIndex {
            // 创建删除后的临时列表
            var tempItems = groupItems
            tempItems.remove(at: index)
            
            if !tempItems.isEmpty {
                // 优先显示同索引位置的item，如果超出范围则显示前一个
                if index < tempItems.count {
                    nextMagnet = tempItems[index]
                } else if index > 0 {
                    nextMagnet = tempItems[index - 1]
                } else {
                    nextMagnet = tempItems[0]
                }
            }
        }
        
        // 执行删除
        store.deleteMagnet(currentMagnet)
        
        DispatchQueue.main.async {
            if let next = nextMagnet {
                // 有下一个item，切换过去
                currentMagnet = next
                loadGroupItems()
                refreshTrigger.toggle()
            } else {
                // 没有下一个item，返回上一级
                dismiss()
            }
        }
    }
}

struct AIDialogView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: MagnetStore
    @Binding var magnet: MagnetItem
    
    @StateObject private var speechService = SpeechService.shared
    @State private var messages: [AIService.Message] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var userInput: String = ""
    @State private var isShowingChat = false
    @State private var activeTask: Task<Void, Never>?
    
    var body: some View {
        let _ = print("🎨 [AIDialogView] Rendering body. Messages: \(messages.count), Loading: \(isLoading)")
        NavigationView {
            VStack(spacing: 0) {
                if isLoading && messages.isEmpty {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("AI 正在思考中...")
                            .padding(.top)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .padding()
                        Button("重试") {
                            loadIntroduction()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 32) {
                                // Introduction Section (Plain Text)
                                if !messages.isEmpty {
                                    let firstMsg = messages[0]
                                    if case .text(let content) = firstMsg.content {
                                        VStack(alignment: .leading, spacing: 28) {
                                            let paragraphs = content.components(separatedBy: "\n")
                                            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                                                let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                                                if !trimmed.isEmpty {
                                                    // Add double ideographic space for indentation and support Markdown
                                                    Text(LocalizedStringKey("\u{3000}\u{3000}\(trimmed)"))
                                                        .font(.system(size: 20, weight: .regular, design: .serif))
                                                        .lineSpacing(16)
                                                        .foregroundColor(.primary.opacity(0.9))
                                                        .multilineTextAlignment(.leading)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.top, 24)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                } else if !isLoading {
                                    // Debug view if messages is empty but not loading
                                    VStack {
                                        Text("暂无科普内容")
                                            .foregroundColor(.secondary)
                                        Button("重新生成") {
                                            loadIntroduction(forceRefresh: true)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 200)
                                }
                                
                                // Chat Section (Bubbles)
                                if messages.count > 1 {
                                    VStack(spacing: 20) {
                                        ForEach(1..<messages.count, id: \.self) { index in
                                            let message = messages[index]
                                            MessageBubble(message: message)
                                                .id(index)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                }
                                
                                if isLoading && !messages.isEmpty {
                                    HStack {
                                        ProgressView()
                                            .padding(.trailing, 8)
                                        Text("AI 正在输入...")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 20)
                                    .id("loading_indicator")
                                }
                                
                                Spacer(minLength: 50)
                                    .id("bottom_spacer")
                            }
                            .padding(.bottom, 30)
                        }
                        .onChange(of: messages.last?.content) { _ in
                            if !messages.isEmpty {
                                withAnimation {
                                    proxy.scrollTo("bottom_spacer", anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: messages.count) { _ in
                            if !messages.isEmpty {
                                withAnimation {
                                    proxy.scrollTo("bottom_spacer", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                
                Divider()
                
                VStack(spacing: 12) {
                    if !isShowingChat {
                        HStack(spacing: 16) {
                            Button(action: {
                                withAnimation {
                                    isShowingChat = true
                                }
                                if speechService.isListening {
                                    speechService.stopListening()
                                } else {
                                    speechService.clearQueue()
                                    speechService.startListening { _ in }
                                }
                            }) {
                                HStack {
                                    Image(systemName: speechService.isListening ? "stop.fill" : "mic.fill")
                                    Text(speechService.isListening ? "正在倾听..." : "语音提问")
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(speechService.isListening ? Color.red : Color.blue)
                                .clipShape(Capsule())
                            }
                            
                            Button(action: {
                                speechService.clearQueue()
                                loadIntroduction(forceRefresh: true)
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("重新生成")
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    } else {
                        HStack {
                            TextField(speechService.isListening ? "正在倾听..." : "问问 AI 更多细节...", text: $userInput)
                                .padding(10)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(20)
                            
                            if userInput.isEmpty {
                                Button(action: {
                                    if speechService.isListening {
                                        speechService.stopListening()
                                    } else {
                                        speechService.clearQueue()
                                        speechService.startListening { _ in }
                                    }
                                }) {
                                    Image(systemName: speechService.isListening ? "stop.fill" : "mic.fill")
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(speechService.isListening ? Color.red : Color.blue)
                                        .clipShape(Circle())
                                }
                            } else {
                                Button(action: {
                                    speechService.clearQueue()
                                    sendMessage()
                                }) {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                }
                                .disabled(isLoading)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                }
                .background(Color(uiColor: .systemBackground))
            }
            .navigationTitle("AI 科普")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        activeTask?.cancel()
                        activeTask = nil
                        speechService.clearQueue()
                        speechService.stopListening()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            print("👋 [AIDialogView] onAppear. Cache status: \(magnet.cachedIntroduction != nil ? "Present (\(magnet.cachedIntroduction!.count) chars)" : "Empty")")
            loadIntroduction()
        }
        .onDisappear {
            activeTask?.cancel()
            activeTask = nil
            speechService.clearQueue()
            speechService.stopListening()
        }
        .onChange(of: speechService.recognizedText) { newText in
            if speechService.isListening {
                userInput = newText
            }
        }
        .onChange(of: speechService.isListening) { isListening in
            if !isListening && !userInput.isEmpty && !isLoading {
                // Auto-send when user stops talking
                withAnimation {
                    isShowingChat = true
                }
                sendMessage()
            }
        }
    }
    
    private func loadIntroduction(forceRefresh: Bool = false) {
        activeTask?.cancel()
        
        if !forceRefresh, let cached = magnet.cachedIntroduction, !cached.isEmpty {
            print("📦 [AIDialogView] Loading from cache. Length: \(cached.count)")
            isLoading = false
            messages = [.init(role: "assistant", content: .text(cached))]
            return
        }
        
        print("🔍 [AIDialogView] No cache found or force refresh. Starting generation...")
        isLoading = true
        errorMessage = nil
        messages = []
        
        activeTask = Task {
            do {
                print("📖 [AIDialogView] Starting introduction generation for: \(magnet.name)")
                let image = ImageManager.shared.loadImage(filename: magnet.imagePath ?? "")
                let stream = AIService.shared.generateIntroductionStream(
                    itemName: magnet.name,
                    location: magnet.location,
                    date: magnet.date,
                    image: image,
                    modelType: store.aiModel
                )
                
                var fullText = ""
                var hasStarted = false
                var lastUpdate = Date()
                
                for try await text in stream {
                    if Task.isCancelled { return }
                    
                    if !hasStarted {
                        await MainActor.run {
                            isLoading = false
                            messages = [.init(role: "assistant", content: .text(""))]
                        }
                        hasStarted = true
                    }
                    
                    fullText += text
                    
                    // Throttle UI updates to 10Hz for better performance and smoothness
                    if Date().timeIntervalSince(lastUpdate) > 0.1 {
                        let currentText = fullText
                        await MainActor.run {
                            if !messages.isEmpty {
                                messages[0] = .init(role: "assistant", content: .text(currentText))
                            }
                        }
                        lastUpdate = Date()
                    }
                }
                
                if Task.isCancelled { return }
                
                // Final update
                let finalFullText = fullText
                await MainActor.run {
                    if !messages.isEmpty {
                        messages[0] = .init(role: "assistant", content: .text(finalFullText))
                    }
                    
                    // Update cache
                    magnet.cachedIntroduction = finalFullText
                    store.updateMagnet(magnet)
                    print("✅ [AIDialogView] Generation complete and cached. Length: \(finalFullText.count)")
                }
            } catch {
                if Task.isCancelled { return }
                print("❌ [AIDialogView] Generation failed: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "生成失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func sendMessage() {
        activeTask?.cancel()
        
        let text = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let userMsg = AIService.Message(role: "user", content: .text(text))
        messages.append(userMsg)
        userInput = ""
        isLoading = true
        
        activeTask = Task {
            do {
                // Include system prompt for chat
                var chatMessages = [AIService.Message(role: "system", content: .text(AIService.shared.chatSystemPrompt))]
                chatMessages.append(contentsOf: messages)
                
                let stream = AIService.shared.chatStream(messages: chatMessages, modelType: store.aiModel)
                
                var fullText = ""
                var hasStarted = false
                var lastUpdate = Date()
                var ttsBuffer = ""
                
                for try await text in stream {
                    if Task.isCancelled { return }
                    
                    if !hasStarted {
                        await MainActor.run {
                            isLoading = false
                            messages.append(.init(role: "assistant", content: .text("")))
                        }
                        hasStarted = true
                    }
                    
                    fullText += text
                    ttsBuffer += text
                    
                    // Check for sentence terminators to trigger streaming TTS
                    if let lastChar = text.last, "。！？.!?".contains(lastChar) {
                        let sentence = ttsBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !sentence.isEmpty {
                            speechService.enqueueAndPlay(sentence)
                            ttsBuffer = ""
                        }
                    }
                    
                    if Date().timeIntervalSince(lastUpdate) > 0.1 {
                        let currentText = fullText
                        await MainActor.run {
                            if messages.count > 1 {
                                messages[messages.count - 1] = .init(role: "assistant", content: .text(currentText))
                            }
                        }
                        lastUpdate = Date()
                    }
                }
                
                if Task.isCancelled { return }
                
                // Final update
                let finalFullText = fullText
                await MainActor.run {
                    if messages.count > 1 {
                        messages[messages.count - 1] = .init(role: "assistant", content: .text(finalFullText))
                    }
                    
                    // Handle remaining text in TTS buffer
                    let remaining = ttsBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !remaining.isEmpty {
                        speechService.enqueueAndPlay(remaining)
                    }
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    errorMessage = "回复失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: AIService.Message
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == "user" { Spacer() }
            
            if message.role == "assistant" {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Circle())
            }
            
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                if case .text(let content) = message.content {
                    Text(LocalizedStringKey(content))
                        .font(.system(size: 16, weight: .medium))
                        .padding(14)
                        .background(message.role == "user" ? Color.blue : Color.gray.opacity(0.08))
                        .foregroundColor(message.role == "user" ? .white : .primary.opacity(0.9))
                        .cornerRadius(18, corners: message.role == "user" ? [.topLeft, .bottomLeft, .bottomRight] : [.topRight, .bottomLeft, .bottomRight])
                }
            }
            .frame(maxWidth: 300, alignment: message.role == "user" ? .trailing : .leading)
            
            if message.role == "user" {
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            
            if message.role == "assistant" { Spacer() }
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview {
    NavigationStack {
        DetailView(magnet: MagnetItem(
            name: "字母B",
            date: Date(),
            location: "上海市黄浦区",
            imagePath: "",
            notes: "终于找到了B，太幸运了！"
        ))
    }
}
