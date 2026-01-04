import SwiftUI
import CoreLocation

struct AddMagnetView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: MagnetStore
    @ObservedObject var locationManager = LocationManager.shared
    
    let image: UIImage
    let originalImage: UIImage?  // Original image with EXIF data
    let gifURL: URL?
    @State private var name: String = ""
    @State private var location: String = "未知位置"
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var notes: String = ""
    @State private var captureDate: Date = Date()
    @State private var isGettingLocation = false
    @State private var isGeneratingNotes = false
    @State private var showingInputDialog = false
    @State private var currentEditingField: Field = .name
    @State private var keyboardHeight: CGFloat = 0
    @State private var dialogHeight: CGFloat = 0
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name
        case notes
    }
    
    init(image: UIImage, originalImage: UIImage? = nil, gifURL: URL? = nil) {
        self.image = image
        self.originalImage = originalImage
        self.gifURL = gifURL
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background with Dotted Pattern (matching reference)
                DottedBackgroundView()
                    .ignoresSafeArea()
                    .onAppear {
                        setupKeyboardObservers()
                    }
                    .onDisappear {
                        removeKeyboardObservers()
                    }
                
                VStack(spacing: 0) {
                    // Top Bar
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Date Header
                    HStack {
                        Text(dateString)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Magnet Image with Glow
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 260, height: 260)
                            .blur(radius: 40)
                        
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 240)
                            .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                    }
                    .padding(.bottom, 40)
                    
                    // Input Triggers
                    VStack(spacing: 12) {
                        // Name Trigger
                        Button(action: {
                            print("🔵 点击名称按钮 - 设置字段为 .name")
                            currentEditingField = .name
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showingInputDialog = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                focusedField = .name
                            }
                        }) {
                            HStack {
                                Text(name.isEmpty ? "点击输入名称..." : name)
                                    .font(.system(size: 18, weight: .medium, design: .rounded))
                                    .foregroundColor(name.isEmpty ? .gray.opacity(0.5) : .primary)
                                Spacer()
                                Image(systemName: "pencil")
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                            .padding(.horizontal, 20)
                            .frame(width: 280, height: 56)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                        }
                        
                        // Notes Trigger
                        Button(action: {
                            print("🟠 点击备注按钮 - 设置字段为 .notes")
                            currentEditingField = .notes
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showingInputDialog = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                focusedField = .notes
                            }
                        }) {
                            HStack(alignment: .top) {
                                Text(notes.isEmpty ? "添加描述 (可选)..." : notes)
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(notes.isEmpty ? .gray.opacity(0.4) : .secondary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                    .frame(minHeight: 40, alignment: .topLeading)
                                Spacer()
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray.opacity(0.4))
                                    .padding(.top, 2)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .frame(width: 280, height: 96)
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.bottom, 20)
                    
                    Spacer()
                    
                    // Bottom Action Buttons (Main Page)
                    if !showingInputDialog {
                        HStack(spacing: 44) {
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                // 重置所有已填入的内容
                                name = ""
                                notes = ""
                                location = "未知位置"
                            }) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundColor(Color.orange.opacity(0.9))
                                    )
                                    .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                            }
                            
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                saveMagnet()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(name.isEmpty ? Color.gray.opacity(0.25) : Color(red: 0.3, green: 0.8, blue: 0.5))
                                        .frame(width: 82, height: 82)
                                    
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 30, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .shadow(color: name.isEmpty ? .clear : Color(red: 0.2, green: 0.7, blue: 0.4).opacity(0.35), radius: 14, x: 0, y: 6)
                            }
                            .disabled(name.isEmpty)
                            
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                // 取消并返回相机页面
                                dismiss()
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let window = windowScene.windows.first {
                                    window.rootViewController?.dismiss(animated: true)
                                }
                            }) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        Image(systemName: "xmark")
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundColor(Color.gray.opacity(0.7))
                                    )
                                    .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                            }
                        }
                        .padding(.bottom, 44)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                
                // Centered Input Dialog (Conditional)
                if showingInputDialog {
                    GeometryReader { geometry in
                        Color.black.opacity(0.15)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation {
                                    showingInputDialog = false
                                    focusedField = nil
                                }
                            }
                        
                        VStack(spacing: 24) {
                            Text(currentEditingField == .name ? "输入对象名称" : "添加描述")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .onAppear {
                                    print("📝 对话框显示 - currentEditingField: \(currentEditingField)")
                                    print("📝 显示标题: \(currentEditingField == .name ? "输入对象名称" : "添加描述")")
                                }
                            
                            ZStack(alignment: .trailing) {
                                Group {
                                    if currentEditingField == .name {
                                        TextField("玩偶", text: $name)
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .multilineTextAlignment(.center)
                                            .focused($focusedField, equals: .name)
                                            .submitLabel(.done)
                                            .lineLimit(1)
                                            .textInputAutocapitalization(.words)
                                            .autocorrectionDisabled(true)
                                            .onSubmit {
                                                withAnimation {
                                                    showingInputDialog = false
                                                    focusedField = nil
                                                }
                                            }
                                            .id("nameField")
                                    } else if currentEditingField == .notes {
                                        HStack(alignment: .center, spacing: 12) {
                                            TextField("添加描述 (可选)", text: $notes, axis: .vertical)
                                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                                .multilineTextAlignment(.leading)
                                                .lineLimit(1...3)
                                                .frame(minHeight: 50)
                                                .focused($focusedField, equals: .notes)
                                                .textInputAutocapitalization(.sentences)
                                                .autocorrectionDisabled(true)
                                                .onChange(of: notes) { newValue in
                                                    let lines = newValue.components(separatedBy: .newlines)
                                                    if lines.count > 3 {
                                                        // 只保留前三行
                                                        notes = lines.prefix(3).joined(separator: "\n")
                                                    }
                                                }
                                                .id("notesField")
                                        
                                            if !name.isEmpty {
                                                Button(action: {
                                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                                    impact.impactOccurred()
                                                    generateNotes()
                                                }) {
                                                    ZStack {
                                                        if isGeneratingNotes {
                                                            ProgressView()
                                                                .scaleEffect(0.7)
                                                                .tint(.orange)
                                                        } else {
                                                            Image(systemName: "sparkles")
                                                                .font(.system(size: 16, weight: .semibold))
                                                                .foregroundColor(.orange)
                                                        }
                                                    }
                                                    .frame(width: 36, height: 36)
                                                    .background(Circle().fill(Color.orange.opacity(0.1)))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            VStack(spacing: 16) {
                                Button(action: {
                                    withAnimation {
                                        showingInputDialog = false
                                        focusedField = nil
                                    }
                                }) {
                                    Text("确定")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.black.opacity(0.8), Color.black.opacity(0.7)]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .cornerRadius(28)
                                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                }
                                
                                Button(action: {
                                    withAnimation {
                                        showingInputDialog = false
                                        focusedField = nil
                                    }
                                }) {
                                    Text("取消")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(30)
                        .background(
                            GeometryReader { dialogGeometry in
                                RoundedRectangle(cornerRadius: 32)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                                    .onAppear {
                                        DispatchQueue.main.async {
                                            dialogHeight = dialogGeometry.size.height
                                        }
                                    }
                                    .onChange(of: dialogGeometry.size.height) { newHeight in
                                        dialogHeight = newHeight
                                    }
                            }
                        )
                        .padding(.horizontal, 40)
                        .position(
                            x: geometry.size.width / 2,
                            y: {
                                let screenHeight = geometry.size.height
                                // 底部间距 + 阴影扩展空间
                                let shadowRadius: CGFloat = 20
                                let bottomMargin: CGFloat = 20 + shadowRadius
                                
                                // 如果对话框高度还没测量出来，先使用一个估计值
                                let actualDialogHeight = dialogHeight > 0 ? dialogHeight : 271
                                
                                // 对话框底部应该在：screenHeight - bottomMargin
                                // 对话框中心Y = 对话框底部Y - 对话框高度的一半
                                let dialogBottomY = screenHeight - bottomMargin
                                let dialogCenterY = dialogBottomY - (actualDialogHeight / 2)
                                
                                // 确保对话框顶部不会超出屏幕
                                let minY = actualDialogHeight / 2 + 20
                                let dialogY = max(minY, dialogCenterY)
                                
                                // 计算实际的对话框底部边缘
                                let actualDialogBottom = dialogY + (actualDialogHeight / 2)
                                
                                print("📱 屏幕高度(可用空间): \(screenHeight)")
                                print("⌨️ 键盘高度: \(keyboardHeight)")
                                print("📦 对话框高度: \(actualDialogHeight) (measured: \(dialogHeight))")
                                print("🌫️  阴影半径: \(shadowRadius)")
                                print("📍 对话框中心Y: \(dialogY)")
                                print("📏 对话框顶部Y: \(dialogY - actualDialogHeight/2)")
                                print("🔽 对话框底部Y(不含阴影): \(actualDialogBottom)")
                                print("🔽 对话框底部Y(含阴影): \(actualDialogBottom + shadowRadius)")
                                print("🔼 键盘上边缘Y: \(screenHeight)")
                                print("📐 对话框底部与键盘的距离(含阴影): \(screenHeight - (actualDialogBottom + shadowRadius))")
                                print("⚠️  是否重叠: \((actualDialogBottom + shadowRadius) > screenHeight ? "是，重叠了 \((actualDialogBottom + shadowRadius) - screenHeight) 点" : "否")")
                                print("---")
                                
                                return dialogY
                            }()
                        )
                        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
                        .animation(.easeOut(duration: 0.25), value: dialogHeight)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.9))
                    ))
                }
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                print("👁️ [AddMagnetView] View appeared")
                print("👁️ [AddMagnetView] Has original image: \(originalImage != nil)")
                extractEXIFData()
            }
            .onChange(of: locationManager.location?.timestamp) { oldValue, newValue in
                if latitude == nil, let _ = newValue {
                    print("📍 [AddMagnetView] Location updated, retrying extraction...")
                    getCurrentLocation()
                }
            }
        }
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月 d日"
        return formatter.string(from: captureDate)
    }
    
    private func extractEXIFData() {
        print("🔍 [AddMagnetView] Starting EXIF extraction...")
        
        // First, try to get EXIF from the cached file URL
        if let fileURL = ImageMetadataCache.shared.getFileURL() {
            print("✅ [AddMagnetView] Found cached file URL: \(fileURL.lastPathComponent)")
            let metadata = EXIFHelper.extractBasicMetadata(from: fileURL)
            
            // Set date from EXIF if available
            if let exifDate = metadata.date {
                print("✅ [AddMagnetView] Setting capture date from file EXIF: \(exifDate)")
                captureDate = exifDate
            } else {
                print("⚠️ [AddMagnetView] No EXIF date found in file")
            }
            
            // Extract location from GPS coordinates
            if let coordinates = metadata.coordinates {
                reverseGeocodeCoordinates(coordinates)
            } else {
                print("⚠️ [AddMagnetView] No GPS coordinates found in file EXIF, trying current location...")
                getCurrentLocation()
            }
            
            // Clean up the cached file
            ImageMetadataCache.shared.clearFileURL()
            return
        }
        
        // Fallback: try to extract from UIImage (less reliable)
        guard let original = originalImage else {
            print("❌ [AddMagnetView] No original image or file URL available")
            return
        }
        
        print("⚠️ [AddMagnetView] No cached file, trying to extract from UIImage...")
        print("✅ [AddMagnetView] Original image available, size: \(original.size)")
        
        let metadata = EXIFHelper.extractBasicMetadata(from: original)
        
        // Set date from EXIF if available
        if let exifDate = metadata.date {
            print("✅ [AddMagnetView] Setting capture date from EXIF: \(exifDate)")
            captureDate = exifDate
        } else {
            print("⚠️ [AddMagnetView] No EXIF date found, using current date")
        }
        
        // Extract location from GPS coordinates
        if let coordinates = metadata.coordinates {
            reverseGeocodeCoordinates(coordinates)
        } else {
            print("⚠️ [AddMagnetView] No GPS coordinates found in EXIF, trying current location...")
            getCurrentLocation()
        }
    }
    
    private func reverseGeocodeCoordinates(_ coordinates: CLLocationCoordinate2D) {
        print("✅ [AddMagnetView] Starting reverse geocoding for coordinates: \(coordinates.latitude), \(coordinates.longitude)")
        self.latitude = coordinates.latitude
        self.longitude = coordinates.longitude
        isGettingLocation = true
        let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [self] placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [AddMagnetView] Geocoding error: \(error.localizedDescription)")
                    self.isGettingLocation = false
                    return
                }
                
                if let placemark = placemarks?.first {
                    print("✅ [AddMagnetView] Received placemark:")
                    print("   Country: \(placemark.country ?? "nil")")
                    print("   Administrative Area: \(placemark.administrativeArea ?? "nil")")
                    print("   Locality: \(placemark.locality ?? "nil")")
                    print("   SubLocality: \(placemark.subLocality ?? "nil")")
                    
                    var locationComponents: [String] = []
                    
                    if let locality = placemark.locality {
                        locationComponents.append(locality)
                    }
                    if let subLocality = placemark.subLocality {
                        locationComponents.append(subLocality)
                    }
                    
                    if !locationComponents.isEmpty {
                        self.location = locationComponents.joined(separator: "")
                        print("✅ [AddMagnetView] Set location to: \(self.location)")
                    } else {
                        print("⚠️ [AddMagnetView] No locality/subLocality found in placemark")
                    }
                } else {
                    print("⚠️ [AddMagnetView] No placemarks received")
                }
                self.isGettingLocation = false
            }
        }
    }
    
    private func processImage() {
        dismiss()
    }
    
    private func saveMagnet() {
        guard !name.isEmpty else { return }
        
        guard let imagePath = ImageManager.shared.saveImage(image) else {
            return
        }
        
        var gifPath: String? = nil
        if let gifURL = gifURL {
            gifPath = ImageManager.shared.saveGIF(from: gifURL)
        }
        
        // If location is still "未知位置" or coordinates are nil, 
        // we ensure they are nil so they don't show up on the map
        let finalLat = (location == "未知位置" || latitude == nil) ? nil : latitude
        let finalLon = (location == "未知位置" || longitude == nil) ? nil : longitude
        
        let magnet = MagnetItem(
            name: name,
            date: captureDate,  // Use EXIF date if available
            location: location,
            latitude: finalLat,
            longitude: finalLon,
            imagePath: imagePath,
            gifPath: gifPath,
            notes: notes
        )
        
        store.addMagnet(magnet)
        
        dismiss()
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.dismiss(animated: true)
        }
    }
    
    private func generateNotes() {
        guard !name.isEmpty else { return }
        
        isGeneratingNotes = true
        
        Task {
            do {
                let modelType = AIModelType(rawValue: store.captionModel) ?? .medium
                let generatedNotes = try await AIService.shared.generateCaption(
                    itemName: name,
                    location: location,
                    date: captureDate,
                    image: image,
                    modelType: modelType
                )
                
                await MainActor.run {
                    self.notes = generatedNotes
                    self.isGeneratingNotes = false
                    
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.success)
                }
            } catch {
                print("❌ [AddMagnetView] Failed to generate notes: \(error)")
                await MainActor.run {
                    self.isGeneratingNotes = false
                    // Fallback to dummy if API fails
                    let templates = [
                        "这是我收藏的\(name)，它有着独特的设计和精致的细节。",
                        "\(name)是我最喜欢的收藏之一，每次看到它都会想起美好的回忆。",
                        "这个\(name)来自\(location)，它承载着特殊的意义。"
                    ]
                    self.notes = templates.randomElement() ?? templates[0]
                }
            }
        }
    }
    
    private func getCurrentLocation() {
        isGettingLocation = true
        
        if let currentLocation = LocationManager.shared.location {
            print("✅ [AddMagnetView] Using location from LocationManager: \(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude)")
            self.latitude = currentLocation.coordinate.latitude
            self.longitude = currentLocation.coordinate.longitude
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(currentLocation) { placemarks, error in
                if let placemark = placemarks?.first {
                    var locationComponents: [String] = []
                    
                    if let city = placemark.locality {
                        locationComponents.append(city)
                    }
                    if let district = placemark.subLocality {
                        locationComponents.append(district)
                    }
                    
                    if !locationComponents.isEmpty {
                        self.location = locationComponents.joined(separator: "")
                        print("✅ [AddMagnetView] Set location to: \(self.location)")
                    }
                }
                isGettingLocation = false
            }
        } else {
            print("⚠️ [AddMagnetView] LocationManager has no location, requesting one-time update...")
            LocationManager.shared.requestLocation()
            
            // Fallback to the old way just in case
            let locationManager = CLLocationManager()
            if let currentLocation = locationManager.location {
                self.latitude = currentLocation.coordinate.latitude
                self.longitude = currentLocation.coordinate.longitude
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(currentLocation) { placemarks, error in
                    if let placemark = placemarks?.first {
                        if let city = placemark.locality, let district = placemark.subLocality {
                            location = "\(city)\(district)"
                        } else if let city = placemark.locality {
                            location = city
                        }
                    }
                    isGettingLocation = false
                }
            } else {
                isGettingLocation = false
            }
        }
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                keyboardHeight = 0
            }
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

#Preview {
    AddMagnetView(image: UIImage(systemName: "photo")!)
        .environmentObject(MagnetStore())
}
