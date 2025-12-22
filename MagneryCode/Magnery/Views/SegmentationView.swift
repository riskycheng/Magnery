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
            
            GeometryReader { geometry in
                Image(uiImage: currentImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .blur(radius: backgroundBlur)
                    .opacity(isProcessing ? 0.3 : 0.2)
            }
            .ignoresSafeArea()
                
            GeometryReader { geometry in
                // Simplified effects for performance
                
                ZStack {
                    // Processing indicator
                    if isProcessing {
                        VStack(spacing: 25) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                                    .frame(width: 60, height: 60)
                                
                                Circle()
                                    .trim(from: 0, to: 0.3)
                                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .frame(width: 60, height: 60)
                                    .rotationEffect(.degrees(rotation))
                                    .onAppear {
                                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                            rotation = 360
                                        }
                                    }
                            }
                            
                            Text(processingText)
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(radius: 5)
                                .scaleEffect(isAnimatingText ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimatingText)
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
                                Image(systemName: "viewfinder")
                                    .font(.system(size: 80, weight: .ultraLight))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Image(systemName: "questionmark")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.white)
                                    .offset(y: 5)
                            }
                            .scaleEffect(isAnimatingText ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimatingText)
                            
                            VStack(spacing: 15) {
                                Text("未检测到明显对象")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("将保存完整图片")
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .multilineTextAlignment(.center)
                            
                            VStack(spacing: 16) {
                                Button(action: {
                                    showingAddView = true
                                }) {
                                    Text("继续")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                        .frame(width: 200, height: 56)
                                        .background(Color.white)
                                        .clipShape(Capsule())
                                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                                }
                                
                                Button(action: {
                                    dismiss()
                                }) {
                                    Text("取消")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(width: 200, height: 56)
                                        .background(Color.white.opacity(0.15))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
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
    
    @State private var rotation: Double = 0.0
    
    private func processImage() {
        isProcessing = true
        noObjectDetected = false
        processingText = "识别中..."
        isAnimatingText = false
        backgroundBlur = 0
        showBorder = false
        segmentedImage = nil
        outlineImage = nil
        foregroundScale = 1.0
        foregroundOpacity = 0.0
        foregroundYOffset = 0
        processingPhase = .initial
        
        VisionService.shared.removeBackground(from: currentImage) { result in
            DispatchQueue.main.async {
                if let result = result {
                    withAnimation {
                        processingPhase = .enhancing
                        self.processingText = "处理中..."
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
                        withAnimation(.easeOut(duration: 0.3)) {
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
