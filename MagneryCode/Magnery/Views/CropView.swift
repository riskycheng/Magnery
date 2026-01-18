import SwiftUI
import UIKit

struct CropView: View {
    @Environment(\.dismiss) var dismiss
    let originalImage: UIImage
    var isAvatarMode: Bool = false
    var onCrop: (UIImage) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var fineRotation: Double = 0
    @State private var selectedAspectRatio: AspectRatio = .original
    @State private var containerSize: CGSize = .zero
    @State private var isInteracting = false
    @State private var interactionTimer: Timer?
    @State private var dragRotationStart: Double = 0
    
    // Crop box state (in view coordinates)
    @State private var cropRect: CGRect = .zero
    
    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 5.0
    private let minCropSize: CGFloat = 50.0
    
    enum AspectRatio: String, CaseIterable {
        case original = "自由"
        case square = "1:1"
        case ratio3_4 = "3:4"
        case ratio4_3 = "4:3"
        case ratio2_3 = "2:3"
        case ratio3_2 = "3:2"
        case ratio9_16 = "9:16"
        case ratio16_9 = "16:9"
        
        var value: CGFloat? {
            switch self {
            case .original: return nil
            case .square: return 1.0
            case .ratio3_4: return 3.0/4.0
            case .ratio4_3: return 4.0/3.0
            case .ratio2_3: return 2.0/3.0
            case .ratio3_2: return 3.0/2.0
            case .ratio9_16: return 9.0/16.0
            case .ratio16_9: return 16.0/9.0
            }
        }
        
        var icon: String {
            switch self {
            case .original: return "rectangle.dashed"
            case .square: return "square"
            case .ratio3_4: return "rectangle.portrait"
            case .ratio4_3: return "rectangle"
            case .ratio2_3: return "rectangle.portrait.fill"
            case .ratio3_2: return "rectangle.fill"
            case .ratio9_16: return "iphone"
            case .ratio16_9: return "tv"
            }
        }
    }
    
    var body: some View {
        GeometryReader { mainGeo in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Text(isAvatarMode ? "编辑头像" : "编辑图片")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .kerning(1)
                        
                        Spacer()
                        
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            cropImage()
                        }) {
                            Text("完成")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.orange)
                                .clipShape(Capsule())
                                .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, mainGeo.safeAreaInsets.top + 5)
                    .padding(.bottom, 15)
                    .background(
                        BlurView(style: .systemUltraThinMaterialDark)
                            .opacity(0.8)
                    )
                    .zIndex(10)
                
                // Main Editing Area
                GeometryReader { geometry in
                    ZStack {
                        // Image
                        Image(uiImage: originalImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .rotationEffect(.degrees(rotation + fineRotation))
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        startInteracting()
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale *= delta
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        stopInteracting()
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        startInteracting()
                                        let translation = value.translation
                                        offset = CGSize(
                                            width: lastOffset.width + translation.width,
                                            height: lastOffset.height + translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                        stopInteracting()
                                    }
                            )
                        
                        // Crop Overlay (Mask)
                        Rectangle()
                            .fill(Color.black.opacity(0.6))
                            .mask(
                                ZStack {
                                    Rectangle()
                                    
                                    if isAvatarMode {
                                        Circle()
                                            .frame(width: cropRect.width, height: cropRect.height)
                                            .offset(x: cropRect.midX - geometry.size.width/2, y: cropRect.midY - geometry.size.height/2)
                                            .blendMode(.destinationOut)
                                    } else {
                                        Rectangle()
                                            .frame(width: cropRect.width, height: cropRect.height)
                                            .offset(x: cropRect.midX - geometry.size.width/2, y: cropRect.midY - geometry.size.height/2)
                                            .blendMode(.destinationOut)
                                    }
                                }
                            )
                            .allowsHitTesting(false)
                        
                        // Grid/Border
                        ZStack {
                            // Border
                            if isAvatarMode {
                                Circle()
                                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
                            } else {
                                Rectangle()
                                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
                            }
                            
                            // 3x3 Grid
                            if isInteracting && !isAvatarMode {
                                GridLines()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                            }
                        }
                        .frame(width: cropRect.width, height: cropRect.height)
                        .position(x: cropRect.midX, y: cropRect.midY)
                        .allowsHitTesting(false)
                        
                        // Corner indicators (Draggable)
                        if !isAvatarMode {
                            cropCorners(in: geometry.size)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        if isAvatarMode {
                            selectedAspectRatio = .square
                        }
                        containerSize = geometry.size
                        initializeCropRect(in: geometry.size)
                    }
                    .onChange(of: selectedAspectRatio) { _ in
                        initializeCropRect(in: geometry.size)
                    }
                }
                .clipped()
                
                // Bottom Controls
                VStack(spacing: 0) {
                    // Fine Rotation Interactive Ruler
                    VStack(spacing: 12) {
                        HStack(spacing: 0) {
                            Text("\(Int(fineRotation))°")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                                .frame(width: 45, alignment: .leading)
                            
                            // Interactive Ruler
                            GeometryReader { rulerGeo in
                                let width = rulerGeo.size.width
                                let midX = width / 2
                                
                                ZStack {
                                    // Background for touch area
                                    Color.clear.contentShape(Rectangle())
                                    
                                    // Moving Ticks
                                    // We draw more ticks to allow for sliding
                                    Canvas { context, size in
                                        let tickCount = 61 // -30 to 30
                                        let spacing: CGFloat = 10
                                        let offset = CGFloat(fineRotation) * spacing
                                        
                                        for i in -tickCount...tickCount {
                                            let x = midX + CGFloat(i) * spacing - offset
                                            
                                            if x >= 0 && x <= size.width {
                                                let isMajor = i % 5 == 0
                                                let height: CGFloat = isMajor ? 16 : 8
                                                let opacity = 1.0 - abs(x - midX) / midX
                                                
                                                var path = Path()
                                                path.move(to: CGPoint(x: x, y: (size.height - height) / 2))
                                                path.addLine(to: CGPoint(x: x, y: (size.height + height) / 2))
                                                
                                                context.stroke(path, with: .color(Color.white.opacity(opacity * (isMajor ? 0.6 : 0.3))), lineWidth: isMajor ? 2 : 1.5)
                                            }
                                        }
                                    }
                                    
                                    // Center Indicator (Static)
                                    Rectangle()
                                        .fill(Color.orange)
                                        .frame(width: 3, height: 24)
                                        .shadow(color: .orange.opacity(0.5), radius: 4)
                                }
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if !isInteracting {
                                                startInteracting()
                                                dragRotationStart = fineRotation
                                            }
                                            
                                            // Sensitivity: 1 point = 0.2 degrees
                                            let delta = Double(value.translation.width) * 0.2
                                            let newValue = dragRotationStart - delta
                                            fineRotation = max(-45, min(45, newValue))
                                            
                                            interactionTimer?.invalidate()
                                        }
                                        .onEnded { _ in
                                            stopInteracting()
                                        }
                                )
                            }
                            .frame(height: 40)
                            
                            Button(action: {
                                withAnimation(.spring()) { fineRotation = 0 }
                            }) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .frame(width: 45, alignment: .trailing)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.03))
                    
                    // Aspect Ratio Selector
                    if !isAvatarMode {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 22) {
                                ForEach(AspectRatio.allCases, id: \.self) { ratio in
                                    Button(action: {
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedAspectRatio = ratio
                                        }
                                    }) {
                                        VStack(spacing: 6) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(selectedAspectRatio == ratio ? Color.orange : Color.white.opacity(0.3), lineWidth: 1.5)
                                                    .frame(width: 22, height: 22)
                                                
                                                Image(systemName: ratio.icon)
                                                    .font(.system(size: 10))
                                                    .foregroundColor(selectedAspectRatio == ratio ? .orange : .white.opacity(0.6))
                                            }
                                            
                                            Text(ratio.rawValue)
                                                .font(.system(size: 10, weight: selectedAspectRatio == ratio ? .bold : .medium))
                                                .foregroundColor(selectedAspectRatio == ratio ? .orange : .white.opacity(0.6))
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 25)
                            .padding(.top, 4) // Prevent truncation
                        }
                        .padding(.vertical, 12)
                    }
                    
                    // Toolbar
                    HStack {
                        Button(action: { 
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            rotate(-90) 
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "rotate.left.fill")
                                    .font(.system(size: 18))
                                Text("左转")
                                    .font(.system(size: 9))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            reset()
                        }) {
                            Text("重置")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button(action: { 
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            rotate(90) 
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "rotate.right.fill")
                                    .font(.system(size: 18))
                                Text("右转")
                                    .font(.system(size: 9))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(.white)
                    .padding(.top, 8)
                    .padding(.bottom, mainGeo.safeAreaInsets.bottom > 0 ? mainGeo.safeAreaInsets.bottom + 5 : 25)
                }
                .background(
                    BlurView(style: .systemUltraThinMaterialDark)
                        .opacity(0.9)
                )
                .zIndex(10)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .top)
                )
            }
            .ignoresSafeArea()
        }
    }
}

    private func startInteracting() {
        if !isInteracting {
            withAnimation(.easeIn(duration: 0.2)) {
                isInteracting = true
            }
        }
    }
    
    private func stopInteracting() {
        withAnimation(.easeOut(duration: 0.3)) {
            isInteracting = false
        }
    }
    
    private func initializeCropRect(in size: CGSize) {
        let padding: CGFloat = 40
        let availableWidth = size.width - (padding * 2)
        let availableHeight = size.height - (padding * 2)
        
        var targetRatio: CGFloat
        if let ratio = selectedAspectRatio.value {
            targetRatio = ratio
        } else {
            targetRatio = originalImage.size.width / originalImage.size.height
            if Int(abs(rotation)) % 180 == 90 {
                targetRatio = 1.0 / targetRatio
            }
        }
        
        var width = availableWidth
        var height = width / targetRatio
        
        if height > availableHeight {
            height = availableHeight
            width = height * targetRatio
        }
        
        cropRect = CGRect(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2,
            width: width,
            height: height
        )
    }
    
    private func cropCorners(in size: CGSize) -> some View {
        let length: CGFloat = 24
        let thickness: CGFloat = 3
        let handleSize: CGFloat = 44 // Larger touch area
        
        return ZStack {
            // Top Left
            cornerHandle(position: .topLeft, size: handleSize) {
                let drag = $0
                let newX = max(0, min(cropRect.maxX - minCropSize, cropRect.origin.x + drag.width))
                let newY = max(0, min(cropRect.maxY - minCropSize, cropRect.origin.y + drag.height))
                
                if let ratio = selectedAspectRatio.value {
                    // Maintain aspect ratio
                    let newWidth = cropRect.maxX - newX
                    let newHeight = newWidth / ratio
                    cropRect = CGRect(x: cropRect.maxX - newWidth, y: cropRect.maxY - newHeight, width: newWidth, height: newHeight)
                } else {
                    cropRect = CGRect(x: newX, y: newY, width: cropRect.maxX - newX, height: cropRect.maxY - newY)
                }
            }
            .position(x: cropRect.minX, y: cropRect.minY)
            
            // Top Right
            cornerHandle(position: .topRight, size: handleSize) {
                let drag = $0
                let newMaxX = min(size.width, max(cropRect.minX + minCropSize, cropRect.maxX + drag.width))
                let newY = max(0, min(cropRect.maxY - minCropSize, cropRect.origin.y + drag.height))
                
                if let ratio = selectedAspectRatio.value {
                    let newWidth = newMaxX - cropRect.minX
                    let newHeight = newWidth / ratio
                    cropRect = CGRect(x: cropRect.minX, y: cropRect.maxY - newHeight, width: newWidth, height: newHeight)
                } else {
                    cropRect = CGRect(x: cropRect.minX, y: newY, width: newMaxX - cropRect.minX, height: cropRect.maxY - newY)
                }
            }
            .position(x: cropRect.maxX, y: cropRect.minY)
            
            // Bottom Left
            cornerHandle(position: .bottomLeft, size: handleSize) {
                let drag = $0
                let newX = max(0, min(cropRect.maxX - minCropSize, cropRect.origin.x + drag.width))
                let newMaxY = min(size.height, max(cropRect.minY + minCropSize, cropRect.maxY + drag.height))
                
                if let ratio = selectedAspectRatio.value {
                    let newWidth = cropRect.maxX - newX
                    let newHeight = newWidth / ratio
                    cropRect = CGRect(x: cropRect.maxX - newWidth, y: cropRect.minY, width: newWidth, height: newHeight)
                } else {
                    cropRect = CGRect(x: newX, y: cropRect.minY, width: cropRect.maxX - newX, height: newMaxY - cropRect.minY)
                }
            }
            .position(x: cropRect.minX, y: cropRect.maxY)
            
            // Bottom Right
            cornerHandle(position: .bottomRight, size: handleSize) {
                let drag = $0
                let newMaxX = min(size.width, max(cropRect.minX + minCropSize, cropRect.maxX + drag.width))
                let newMaxY = min(size.height, max(cropRect.minY + minCropSize, cropRect.maxY + drag.height))
                
                if let ratio = selectedAspectRatio.value {
                    let newWidth = newMaxX - cropRect.minX
                    let newHeight = newWidth / ratio
                    cropRect = CGRect(x: cropRect.minX, y: cropRect.minY, width: newWidth, height: newHeight)
                } else {
                    cropRect = CGRect(x: cropRect.minX, y: cropRect.minY, width: newMaxX - cropRect.minX, height: newMaxY - cropRect.minY)
                }
            }
            .position(x: cropRect.maxX, y: cropRect.maxY)
            
            // Visual Corners
            Group {
                // Top Left
                cornerShape(length: length, thickness: thickness, position: .topLeft)
                    .position(x: cropRect.minX + length/2 - thickness/2, y: cropRect.minY + length/2 - thickness/2)
                
                // Top Right
                cornerShape(length: length, thickness: thickness, position: .topRight)
                    .position(x: cropRect.maxX - length/2 + thickness/2, y: cropRect.minY + length/2 - thickness/2)
                
                // Bottom Left
                cornerShape(length: length, thickness: thickness, position: .bottomLeft)
                    .position(x: cropRect.minX + length/2 - thickness/2, y: cropRect.maxY - length/2 + thickness/2)
                
                // Bottom Right
                cornerShape(length: length, thickness: thickness, position: .bottomRight)
                    .position(x: cropRect.maxX - length/2 + thickness/2, y: cropRect.maxY - length/2 + thickness/2)
            }
            .foregroundColor(.white)
            .allowsHitTesting(false)
        }
    }
    
    enum CornerPosition {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    private func cornerHandle(position: CornerPosition, size: CGFloat, onDrag: @escaping (CGSize) -> Void) -> some View {
        Color.clear
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        startInteracting()
                        onDrag(value.translation)
                    }
                    .onEnded { _ in
                        stopInteracting()
                    }
            )
    }
    
    private func cornerShape(length: CGFloat, thickness: CGFloat, position: CornerPosition) -> some View {
        Path { path in
            switch position {
            case .topLeft:
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))
            case .topRight:
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))
                path.addLine(to: CGPoint(x: length, y: length))
            case .bottomLeft:
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: length, y: length))
            case .bottomRight:
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: length, y: length))
                path.addLine(to: CGPoint(x: length, y: 0))
            }
        }
        .stroke(Color.white, lineWidth: thickness)
        .frame(width: length, height: length)
    }
    
    private func rotate(_ degrees: Double) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            rotation += degrees
        }
    }
    
    private func reset() {
        withAnimation(.spring()) {
            scale = 1.0
            offset = .zero
            lastScale = 1.0
            lastOffset = .zero
            rotation = 0
            fineRotation = 0
            selectedAspectRatio = .original
        }
    }
    
    private func cropImage() {
        // 1. Handle rotation (both 90-degree and fine-tuning)
        let totalRotation = rotation + fineRotation
        guard let rotatedImage = originalImage.rotated(by: Measurement(value: totalRotation, unit: .degrees)) else {
            onCrop(originalImage)
            dismiss()
            return
        }
        
        // 2. Calculate coordinates
        // Calculate the image's display size (fitted in container)
        let widthRatio = containerSize.width / rotatedImage.size.width
        let heightRatio = containerSize.height / rotatedImage.size.height
        let baseScale = min(widthRatio, heightRatio)
        
        let totalScale = baseScale * scale
        
        // Image center in view coordinates
        let imageCenterInView = CGPoint(
            x: containerSize.width / 2 + offset.width,
            y: containerSize.height / 2 + offset.height
        )
        
        // Crop rect center relative to image center in view coordinates
        let cropCenterRelativeToImage = CGPoint(
            x: cropRect.midX - imageCenterInView.x,
            y: cropRect.midY - imageCenterInView.y
        )
        
        // Convert to image coordinates
        let imageCenter = CGPoint(x: rotatedImage.size.width / 2, y: rotatedImage.size.height / 2)
        let cropCenterInImage = CGPoint(
            x: imageCenter.x + (cropCenterRelativeToImage.x / totalScale),
            y: imageCenter.y + (cropCenterRelativeToImage.y / totalScale)
        )
        
        let cropWidthInImage = cropRect.width / totalScale
        let cropHeightInImage = cropRect.height / totalScale
        
        let cropRectInImage = CGRect(
            x: cropCenterInImage.x - cropWidthInImage / 2,
            y: cropCenterInImage.y - cropHeightInImage / 2,
            width: cropWidthInImage,
            height: cropHeightInImage
        )
        
        // 3. Crop
        if let cgImage = rotatedImage.cgImage?.cropping(to: cropRectInImage) {
            let croppedUIImage = UIImage(cgImage: cgImage, scale: originalImage.scale, orientation: .up)
            onCrop(croppedUIImage)
        } else {
            onCrop(rotatedImage)
        }
        
        dismiss()
    }
}

struct GridLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Vertical lines
        path.move(to: CGPoint(x: rect.width / 3, y: 0))
        path.addLine(to: CGPoint(x: rect.width / 3, y: rect.height))
        
        path.move(to: CGPoint(x: rect.width * 2 / 3, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 2 / 3, y: rect.height))
        
        // Horizontal lines
        path.move(to: CGPoint(x: 0, y: rect.height / 3))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height / 3))
        
        path.move(to: CGPoint(x: 0, y: rect.height * 2 / 3))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 2 / 3))
        
        return path
    }
}

// Helper for rotation
extension UIImage {
    func rotated(by angle: Measurement<UnitAngle>) -> UIImage? {
        let radians = CGFloat(angle.converted(to: .radians).value)
        
        var newSize = CGRect(origin: .zero, size: self.size)
            .applying(CGAffineTransform(rotationAngle: radians)).size
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        context.rotate(by: radians)
        
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}
