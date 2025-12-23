import SwiftUI
import CoreImage.CIFilterBuiltins

// Simplified, lightweight glow effect (no continuous animations)
struct AnimatedGlowOutline: View {
    let outlineImage: UIImage
    @State private var glowIntensity: Double = 0.0
    
    var body: some View {
        Image(uiImage: outlineImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .shadow(color: .white.opacity(0.6), radius: 15, x: 0, y: 0)
            .shadow(color: .blue.opacity(0.4), radius: 25, x: 0, y: 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0)) {
                    glowIntensity = 1.0
                }
            }
    }
}

struct ParticleView: View {
    @State private var position = CGPoint(
        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
    )
    @State private var opacity = Double.random(in: 0.1...0.4)
    @State private var scale = CGFloat.random(in: 0.5...1.5)
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 4, height: 4)
            .position(position)
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.linear(duration: Double.random(in: 5...10)).repeatForever(autoreverses: true)) {
                    position = CGPoint(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    opacity = Double.random(in: 0.1...0.4)
                }
            }
    }
}

struct TechGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 30
        
        for x in stride(from: 0, through: rect.width, by: step) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        for y in stride(from: 0, through: rect.height, by: step) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        return path
    }
}

struct CornerAccents: Shape {
    let size: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length: CGFloat = 30
        let padding: CGFloat = 40
        
        // Top Left
        path.move(to: CGPoint(x: padding, y: padding + length))
        path.addLine(to: CGPoint(x: padding, y: padding))
        path.addLine(to: CGPoint(x: padding + length, y: padding))
        
        // Top Right
        path.move(to: CGPoint(x: rect.width - padding - length, y: padding))
        path.addLine(to: CGPoint(x: rect.width - padding, y: padding))
        path.addLine(to: CGPoint(x: rect.width - padding, y: padding + length))
        
        // Bottom Left
        path.move(to: CGPoint(x: padding, y: rect.height - padding - length))
        path.addLine(to: CGPoint(x: padding, y: rect.height - padding))
        path.addLine(to: CGPoint(x: padding + length, y: rect.height - padding))
        
        // Bottom Right
        path.move(to: CGPoint(x: rect.width - padding - length, y: rect.height - padding))
        path.addLine(to: CGPoint(x: rect.width - padding, y: rect.height - padding))
        path.addLine(to: CGPoint(x: rect.width - padding, y: rect.height - padding - length))
        
        return path
    }
}

struct SegmentationView: View {
    @Environment(\.dismiss) var dismiss
    let originalImage: UIImage
    @State private var segmentedImage: UIImage?
    @State private var outlineImage: UIImage?
    @State private var isProcessing = true
    @State private var showingAddView = false
    @State private var showingCropView = false
    @State private var backgroundBlur: CGFloat = 0
    @State private var showBorder = false
    @State private var currentImage: UIImage
    @State private var foregroundScale: CGFloat = 1.0
    @State private var foregroundOpacity: Double = 0.0
    @State private var foregroundYOffset: CGFloat = 0
    @State private var processingPhase: ProcessingPhase = .initial
    @State private var noObjectDetected = false
    @State private var processingText = "识别中..."
    @State private var isAnimatingText = false
    @State private var scanOffset: CGFloat = -1.0
    @State private var rotation: Double = 0.0
    @State private var processingProgress: Double = 0.0
    
    enum ProcessingPhase {
        case initial
        case detecting
        case separating
        case enhancing
        case complete
    }
    
    init(originalImage: UIImage) {
        self.originalImage = originalImage
        _currentImage = State(initialValue: originalImage)
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if isProcessing {
                // Background tech grid
                TechGrid()
                    .stroke(Color.white.opacity(0.03), lineWidth: 1)
                    .ignoresSafeArea()
                
                // Floating particles
                ForEach(0..<15) { i in
                    ParticleView()
                }
            }
            
            GeometryReader { geometry in
                Image(uiImage: currentImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .blur(radius: backgroundBlur)
                    .opacity(isProcessing ? 0.3 : 0.2)
                    .overlay(
                        ZStack {
                            if isProcessing {
                                // Tech grid overlay
                                Path { path in
                                    let step: CGFloat = 40
                                    for x in stride(from: 0, through: geometry.size.width, by: step) {
                                        path.move(to: CGPoint(x: x, y: 0))
                                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                                    }
                                    for y in stride(from: 0, through: geometry.size.height, by: step) {
                                        path.move(to: CGPoint(x: 0, y: y))
                                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                                    }
                                }
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                
                                // Corner accents
                                CornerAccents(size: geometry.size)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                            }
                        }
                    )
            }
            .ignoresSafeArea()
                
            GeometryReader { geometry in
                // Simplified effects for performance
                
                ZStack {
                    // Scanning Line Effect
                    if isProcessing {
                        ZStack {
                            // Main line
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.clear, .white.opacity(0.8), .clear]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: 2)
                            
                            // Glow
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.clear, .orange.opacity(0.3), .clear]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: 40)
                        }
                        .offset(y: geometry.size.height * scanOffset)
                        .onAppear {
                            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: true)) {
                                scanOffset = 1.0
                            }
                        }
                        .onChange(of: scanOffset) { oldValue, newValue in
                            // Add a subtle haptic when the scan line passes the middle or ends
                            if abs(newValue - 0.5) < 0.01 || abs(newValue - 1.0) < 0.01 || abs(newValue - 0.0) < 0.01 {
                                let impact = UIImpactFeedbackGenerator(style: .soft)
                                impact.impactOccurred(intensity: 0.5)
                            }
                        }
                        .zIndex(5)
                    }
                    
                    // Processing indicator
                    if isProcessing {
                        VStack(spacing: 30) {
                            ZStack {
                                // Outer glowing ring
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                                    .frame(width: 100, height: 100)
                                
                                // Middle rotating ring
                                Circle()
                                    .trim(from: 0, to: 0.4)
                                    .stroke(
                                        LinearGradient(colors: [.white, .white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                    )
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(rotation))
                                
                                // Inner rotating ring (opposite direction)
                                Circle()
                                    .trim(from: 0, to: 0.3)
                                    .stroke(
                                        LinearGradient(colors: [.orange, .orange.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                                    )
                                    .frame(width: 60, height: 60)
                                    .rotationEffect(.degrees(-rotation * 1.5))
                                
                                // Center dot
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: .white, radius: 10)
                                
                                // Progress percentage
                                Text("\(Int(processingProgress * 100))%")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                                    .offset(y: 25)
                            }
                            .onAppear {
                                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                    rotation = 360
                                }
                            }
                            
                            VStack(spacing: 8) {
                                Text(processingText)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(radius: 10)
                                
                                if processingPhase == .initial || processingPhase == .detecting {
                                    Text("正在分析图像特征...")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.6))
                                        .transition(.opacity)
                                } else {
                                    Text("AI 正在智能提取主体...")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.6))
                                        .transition(.opacity)
                                }
                            }
                            .scaleEffect(isAnimatingText ? 1.02 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimatingText)
                            .onAppear {
                                isAnimatingText = true
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                        .zIndex(10)
                    }
                    
                    // No object detected message
                    if noObjectDetected {
                        VStack(spacing: 40) {
                            ZStack {
                                // Outer glowing ring (static)
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "viewfinder")
                                    .font(.system(size: 80, weight: .ultraLight))
                                    .foregroundColor(.white.opacity(0.4))
                                
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.orange)
                                    .background(Circle().fill(Color.black))
                                    .offset(x: 30, y: -30)
                            }
                            .scaleEffect(isAnimatingText ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimatingText)
                            
                            VStack(spacing: 15) {
                                Text("未检测到明显对象")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("AI 无法自动分离背景\n我们将为您保留完整图片")
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                            }
                            
                            VStack(spacing: 16) {
                                Button(action: {
                                    showingAddView = true
                                }) {
                                    HStack {
                                        Text("继续保存")
                                        Image(systemName: "arrow.right")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .frame(width: 220, height: 56)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                                    .shadow(color: .white.opacity(0.2), radius: 15)
                                }
                                
                                Button(action: {
                                    dismiss()
                                }) {
                                    Text("返回重拍")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(width: 220, height: 56)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                        .onAppear {
                            isAnimatingText = true
                        }
                        .zIndex(10)
                    }
                    
                    VStack {
                        if !isProcessing && !noObjectDetected {
                            HStack {
                                Text(dateString)
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.leading, 20)
                                
                                Spacer()
                            }
                            .padding(.top, 20)
                            .transition(.opacity)
                        }
                        
                        Spacer()
                        
                        if !isProcessing && !noObjectDetected {
                            HStack(spacing: 60) {
                                Button(action: {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    dismiss()
                                }) {
                                    Circle()
                                        .fill(Color.gray.opacity(0.8))
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Image(systemName: "arrow.counterclockwise")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                        )
                                }
                                
                                Button(action: {
                                    if segmentedImage != nil {
                                        let impact = UIImpactFeedbackGenerator(style: .medium)
                                        impact.impactOccurred()
                                        showingAddView = true
                                    }
                                }) {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 70, height: 70)
                                        .overlay(
                                            Image(systemName: "checkmark")
                                                .font(.title)
                                                .foregroundColor(.black)
                                        )
                                }
                                .disabled(segmentedImage == nil)
                                
                                Button(action: {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    showingCropView = true
                                }) {
                                    Circle()
                                        .fill(Color.gray.opacity(0.8))
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Image(systemName: "crop")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                            .padding(.bottom, 40)
                            .transition(.opacity)
                        }
                    }
                    
                    if let image = segmentedImage, foregroundOpacity > 0 {
                        let maxWidth = geometry.size.width * 0.85
                        let maxHeight = geometry.size.height * 0.75
                        let imageSize = image.size
                        let widthRatio = maxWidth / imageSize.width
                        let heightRatio = maxHeight / imageSize.height
                        let ratio = min(widthRatio, heightRatio)
                        let finalWidth = imageSize.width * ratio
                        let finalHeight = imageSize.height * ratio
                        
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .frame(width: finalWidth, height: finalHeight)
                                .scaleEffect(foregroundScale)
                                .opacity(foregroundOpacity)
                                .shadow(color: .white.opacity(0.3 * foregroundOpacity), radius: 20, x: 0, y: 0)
                                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                                .onAppear {
                                    print("🔵 Image appeared - Scale: \(foregroundScale), Opacity: \(foregroundOpacity)")
                                    print("🔵 Geometry size: \(geometry.size)")
                                    print("🔵 Image size: \(imageSize)")
                                    print("🔵 Final size: \(finalWidth) x \(finalHeight)")
                                    print("🔵 Position: center (\(geometry.size.width / 2), \(geometry.size.height / 2))")
                                }
                                .onChange(of: foregroundScale) { oldValue, newValue in
                                    print("📏 Scale changed: \(oldValue) → \(newValue)")
                                }
                                .onChange(of: foregroundOpacity) { oldValue, newValue in
                                    print("👁️ Opacity changed: \(oldValue) → \(newValue)")
                                }
                            
                            if showBorder, let outline = outlineImage {
                                AnimatedGlowOutline(outlineImage: outline)
                                    .frame(width: finalWidth, height: finalHeight)
                                    .scaleEffect(foregroundScale)
                                    .opacity(foregroundOpacity)
                                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                            }
                        }
                        .onChange(of: geometry.size) { oldValue, newValue in
                            print("📐 Geometry size changed: \(oldValue) → \(newValue)")
                        }
                    }
                }
            }
        }
        .onAppear {
            if segmentedImage == nil {
                processImage()
            }
        }
        .fullScreenCover(isPresented: $showingAddView) {
            if let image = segmentedImage {
                let squareImage = ImageOutlineHelper.padToSquare(image: image) ?? image
                AddMagnetView(image: squareImage, originalImage: originalImage)
                    .onAppear {
                        print("🎨 [SegmentationView] Opening AddMagnetView")
                        print("🎨 [SegmentationView] Segmented image size: \(image.size)")
                        print("🎨 [SegmentationView] Original image size: \(originalImage.size)")
                    }
            }
        }
        .fullScreenCover(isPresented: $showingCropView) {
            CropView(originalImage: currentImage) { croppedImage in
                currentImage = croppedImage
                processImage()
            }
        }
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: Date())
    }
    
    private func processImage() {
        isProcessing = true
        noObjectDetected = false
        processingText = "AI 深度识别中..."
        isAnimatingText = false
        processingProgress = 0.0
        backgroundBlur = 0
        showBorder = false
        segmentedImage = nil
        outlineImage = nil
        foregroundScale = 1.0
        foregroundOpacity = 0.0
        foregroundYOffset = 0
        processingPhase = .initial
        
        // Start progress animation
        withAnimation(.linear(duration: 3.0)) {
            processingProgress = 0.95
        }
        
        VisionService.shared.removeBackground(from: currentImage) { result in
            DispatchQueue.main.async {
                if let result = result {
                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                    impactMed.impactOccurred()
                    
                    withAnimation {
                        processingPhase = .enhancing
                        self.processingText = "正在提取主体..."
                    }
                    
                    // Use maxHeight to fit screen better
                    let screenSize = UIScreen.main.bounds
                    let maxDisplayHeight = screenSize.height * 0.6  // 60% of screen height
                    let maxDisplayWidth = screenSize.width * 0.85   // 85% of screen width
                    
                    // Calculate scale factor based on both dimensions
                    let heightRatio = result.image.size.height / maxDisplayHeight
                    let widthRatio = result.image.size.width / maxDisplayWidth
                    let scaleFactor = max(heightRatio, widthRatio)
                    
                    let offset = 10.0 * scaleFactor
                    let lineWidth = 4.0 * scaleFactor
                    let padding = offset + lineWidth + 20.0
                    
                    if let paddedImage = ImageOutlineHelper.addPadding(to: result.image, amount: padding) {
                        self.segmentedImage = paddedImage
                        print("✅ Segmented image set (padded): \(paddedImage.size)")
                        self.outlineImage = ImageOutlineHelper.createOutline(from: paddedImage, lineWidth: lineWidth, offset: offset)
                    } else {
                        self.segmentedImage = result.image
                        print("✅ Segmented image set (original): \(result.image.size)")
                        self.outlineImage = ImageOutlineHelper.createOutline(from: result.image, lineWidth: lineWidth, offset: offset)
                    }
                    
                    // Simplified animation sequence for performance
                    print("🎬 Starting simplified animation...")
                    
                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                    impactLight.prepare()
                    impactLight.impactOccurred()
                    
                    withAnimation(.easeOut(duration: 0.4)) {
                        self.backgroundBlur = 30
                    }
                    
                    withAnimation(.interpolatingSpring(stiffness: 120, damping: 15).delay(0.2)) {
                        self.foregroundScale = 1.1
                        self.foregroundOpacity = 1.0
                    }
                    
                    let impactHeavy = UIImpactFeedbackGenerator(style: .medium)
                    impactHeavy.prepare()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        impactHeavy.impactOccurred()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            self.showBorder = true
                            self.foregroundScale = 1.0
                        }
                        
                        let notificationSuccess = UINotificationFeedbackGenerator()
                        notificationSuccess.notificationOccurred(.success)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        let notificationSuccess = UINotificationFeedbackGenerator()
                        notificationSuccess.notificationOccurred(.success)
                        
                        withAnimation(.easeOut(duration: 0.3)) {
                            self.processingProgress = 1.0
                            self.isProcessing = false
                        }
                    }
                } else {
                    // No object detected
                    print("⚠️ No foreground object detected, using original image")
                    self.segmentedImage = self.originalImage
                    withAnimation(.spring()) {
                        self.noObjectDetected = true
                        self.isProcessing = false
                    }
                }
            }
        }
    }
}

#Preview {
    SegmentationView(originalImage: UIImage(systemName: "photo")!)
}
