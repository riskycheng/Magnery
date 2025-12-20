import SwiftUI
import CoreImage.CIFilterBuiltins

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var opacity: Double
    var scale: CGFloat
    var color: Color
    var lifetime: Double
}

struct BackgroundParticleSystem: View {
    @State private var particles: [Particle] = []
    let screenSize: CGSize
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                
                for particle in particles {
                    let age = now - particle.lifetime
                    if age > 3.0 { continue }
                    
                    let progress = age / 3.0
                    let currentOpacity = particle.opacity * (1.0 - progress)
                    let currentScale = particle.scale * (1.0 + progress * 2.0)
                    
                    var particleContext = context
                    particleContext.opacity = currentOpacity
                    
                    let rect = CGRect(
                        x: particle.position.x - currentScale / 2,
                        y: particle.position.y - currentScale / 2,
                        width: currentScale,
                        height: currentScale
                    )
                    
                    particleContext.fill(
                        Path(ellipseIn: rect),
                        with: .color(particle.color)
                    )
                }
            }
        }
        .onAppear {
            generateBackgroundParticles()
            startBackgroundAnimation()
        }
    }
    
    private func generateBackgroundParticles() {
        let colors: [Color] = [
            .white.opacity(0.6), .cyan.opacity(0.5), .blue.opacity(0.4),
            .purple.opacity(0.3), .pink.opacity(0.3)
        ]
        
        particles = (0..<200).map { _ in
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 100...300)
            let startX = screenSize.width / 2
            let startY = screenSize.height / 2
            
            return Particle(
                position: CGPoint(
                    x: startX + CGFloat.random(in: -100...100),
                    y: startY + CGFloat.random(in: -100...100)
                ),
                velocity: CGPoint(
                    x: cos(angle) * speed,
                    y: sin(angle) * speed
                ),
                opacity: Double.random(in: 0.3...0.7),
                scale: CGFloat.random(in: 2...6),
                color: colors.randomElement() ?? .white,
                lifetime: Date().timeIntervalSinceReferenceDate
            )
        }
    }
    
    private func startBackgroundAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            if particles.isEmpty {
                timer.invalidate()
                return
            }
            
            let now = Date().timeIntervalSinceReferenceDate
            particles = particles.map { particle in
                var updated = particle
                let dt: CGFloat = 0.016
                updated.position.x += particle.velocity.x * dt
                updated.position.y += particle.velocity.y * dt
                return updated
            }.filter { now - $0.lifetime < 3.0 }
        }
    }
}

struct ParticleSystem: View {
    let particleCount: Int
    let sourceRect: CGRect
    @State private var particles: [Particle] = []
    @State private var isAnimating = false
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                
                for particle in particles {
                    let age = now - particle.lifetime
                    if age > 2.0 { continue }
                    
                    let progress = age / 2.0
                    let currentOpacity = particle.opacity * (1.0 - progress)
                    let currentScale = particle.scale * (1.0 + progress * 0.5)
                    
                    var particleContext = context
                    particleContext.opacity = currentOpacity
                    
                    let rect = CGRect(
                        x: particle.position.x - currentScale / 2,
                        y: particle.position.y - currentScale / 2,
                        width: currentScale,
                        height: currentScale
                    )
                    
                    particleContext.fill(
                        Path(ellipseIn: rect),
                        with: .color(particle.color)
                    )
                }
            }
        }
        .onAppear {
            generateParticles()
            startAnimation()
        }
    }
    
    private func generateParticles() {
        let colors: [Color] = [
            .white, .blue.opacity(0.8), .cyan.opacity(0.8),
            .purple.opacity(0.6), .pink.opacity(0.6)
        ]
        
        particles = (0..<particleCount).map { _ in
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 50...150)
            
            return Particle(
                position: CGPoint(
                    x: sourceRect.midX + CGFloat.random(in: -sourceRect.width/4...sourceRect.width/4),
                    y: sourceRect.midY + CGFloat.random(in: -sourceRect.height/4...sourceRect.height/4)
                ),
                velocity: CGPoint(
                    x: cos(angle) * speed,
                    y: sin(angle) * speed
                ),
                opacity: Double.random(in: 0.4...0.9),
                scale: CGFloat.random(in: 3...8),
                color: colors.randomElement() ?? .white,
                lifetime: Date().timeIntervalSinceReferenceDate
            )
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if particles.isEmpty {
                timer.invalidate()
                return
            }
            
            let now = Date().timeIntervalSinceReferenceDate
            particles = particles.map { particle in
                var updated = particle
                let dt: CGFloat = 0.016
                updated.position.x += particle.velocity.x * dt
                updated.position.y += particle.velocity.y * dt
                return updated
            }.filter { now - $0.lifetime < 2.0 }
            
            if particles.count < particleCount / 2 {
                let newParticles = generateNewParticles(count: 5)
                particles.append(contentsOf: newParticles)
            }
        }
    }
    
    private func generateNewParticles(count: Int) -> [Particle] {
        let colors: [Color] = [
            .white, .blue.opacity(0.8), .cyan.opacity(0.8),
            .purple.opacity(0.6), .pink.opacity(0.6)
        ]
        
        return (0..<count).map { _ in
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 50...150)
            
            return Particle(
                position: CGPoint(
                    x: sourceRect.midX + CGFloat.random(in: -sourceRect.width/4...sourceRect.width/4),
                    y: sourceRect.midY + CGFloat.random(in: -sourceRect.height/4...sourceRect.height/4)
                ),
                velocity: CGPoint(
                    x: cos(angle) * speed,
                    y: sin(angle) * speed
                ),
                opacity: Double.random(in: 0.4...0.9),
                scale: CGFloat.random(in: 3...8),
                color: colors.randomElement() ?? .white,
                lifetime: Date().timeIntervalSinceReferenceDate
            )
        }
    }
}


struct AnimatedGlowOutline: View {
    let outlineImage: UIImage
    @State private var glowIntensity: Double = 0.0
    @State private var rotation: Double = 0.0
    
    var body: some View {
        ZStack {
            Image(uiImage: outlineImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .shadow(color: .cyan.opacity(glowIntensity * 0.8), radius: 20, x: 0, y: 0)
                .shadow(color: .blue.opacity(glowIntensity * 0.6), radius: 30, x: 0, y: 0)
                .shadow(color: .purple.opacity(glowIntensity * 0.4), radius: 40, x: 0, y: 0)
            
            FlowingOutlineView(outlineImage: outlineImage)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowIntensity = 1.0
            }
        }
    }
}

struct FlowingOutlineView: View {
    let outlineImage: UIImage
    
    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let period: Double = 1.5
            let progress = (time.truncatingRemainder(dividingBy: period)) / period
            let offset = CGFloat(progress) * 30.0
            
            Canvas { ctx, size in
                let dashWidth: CGFloat = 10
                let gapWidth: CGFloat = 5
                let patternWidth = dashWidth + gapWidth
                let height = size.height
                let width = size.width
                
                let start = -20
                let end = Int(height / patternWidth) + 20
                
                for i in start..<end {
                    let y = CGFloat(i) * patternWidth + offset
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                    ctx.stroke(path, with: .color(.white), lineWidth: dashWidth)
                }
            }
        }
        .mask(
            Image(uiImage: outlineImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        )
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
    @State private var showParticles = false
    @State private var showBackgroundParticles = false
    @State private var processingPhase: ProcessingPhase = .initial
    @State private var vignetteIntensity: CGFloat = 0.0
    @State private var contourFocus: CGFloat = 0.0
    
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
                if isProcessing {
                    Rectangle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .clear,
                                    .black.opacity(vignetteIntensity)
                                ],
                                center: .center,
                                startRadius: 100,
                                endRadius: 400
                            )
                        )
                        .ignoresSafeArea()
                }
                
                if showBackgroundParticles {
                    BackgroundParticleSystem(screenSize: geometry.size)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
                
                if showParticles {
                    ParticleSystem(
                        particleCount: 80,
                        sourceRect: CGRect(
                            x: geometry.size.width / 2 - 100,
                            y: geometry.size.height / 2 - 100,
                            width: 200,
                            height: 200
                        )
                    )
                    .ignoresSafeArea()
                }
                
                ZStack {
                    VStack {
                        if !isProcessing {
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
                        
                        if !isProcessing {
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
                AddMagnetView(image: squareImage)
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
        backgroundBlur = 0
        showBorder = false
        segmentedImage = nil
        outlineImage = nil
        foregroundScale = 1.0
        foregroundOpacity = 0.0
        foregroundYOffset = 0
        showParticles = false
        showBackgroundParticles = false
        processingPhase = .initial
        vignetteIntensity = 0.0
        contourFocus = 0.0
        
        VisionService.shared.removeBackground(from: currentImage) { result in
            DispatchQueue.main.async {
                if let result = result {
                    withAnimation {
                        processingPhase = .enhancing
                    }
                    
                    let displayHeight = UIScreen.main.bounds.height * 0.5
                    let scaleFactor = result.image.size.height / displayHeight
                    
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
                    
                    print("🎬 Starting animation sequence...")
                    print("   Initial state - Scale: \(self.foregroundScale), Opacity: \(self.foregroundOpacity)")
                    
                    withAnimation(.easeIn(duration: 0.8)) {
                        self.vignetteIntensity = 0.6
                        print("🌑 Vignette intensity: 0 → 0.6")
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("💥 Particles and blur starting...")
                        self.showBackgroundParticles = true
                        self.showParticles = true
                        
                        withAnimation(.easeOut(duration: 0.5)) {
                            self.vignetteIntensity = 0.0
                            self.contourFocus = 1.0
                            print("🌑 Vignette intensity: 0.6 → 0")
                        }
                        
                        withAnimation(.easeOut(duration: 0.6)) {
                            self.backgroundBlur = 30
                            print("🌫️ Background blur: 0 → 30")
                        }
                        
                        print("🎯 Object reveal animation starting (delay 0.2s)...")
                        withAnimation(.interpolatingSpring(stiffness: 100, damping: 12).delay(0.2)) {
                            print("   Before animation - Scale: \(self.foregroundScale), Opacity: \(self.foregroundOpacity)")
                            self.foregroundScale = 1.15
                            self.foregroundOpacity = 1.0
                            print("   After animation - Scale: 1.15, Opacity: 1.0")
                        }
                        
                        let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                        impactHeavy.prepare()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            impactHeavy.impactOccurred()
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                self.showBorder = true
                            }
                            
                            withAnimation(.interpolatingSpring(stiffness: 120, damping: 15)) {
                                self.foregroundScale = 1.0
                            }
                            
                            let notificationSuccess = UINotificationFeedbackGenerator()
                            notificationSuccess.notificationOccurred(.success)
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation(.easeOut(duration: 0.4)) {
                                self.isProcessing = false
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.easeOut(duration: 0.4)) {
                                    self.showParticles = false
                                    self.showBackgroundParticles = false
                                }
                            }
                        }
                    }
                } else {
                    self.segmentedImage = originalImage
                    self.isProcessing = false
                }
            }
        }
    }
}

#Preview {
    SegmentationView(originalImage: UIImage(systemName: "photo")!)
}
