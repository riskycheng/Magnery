import SwiftUI
import UIKit

struct CropView: View {
    @Environment(\.dismiss) var dismiss
    let originalImage: UIImage
    var onCrop: (UIImage) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var showingAspectRatioMenu = false
    @State private var selectedAspectRatio: AspectRatio = .original
    @State private var cropArea: CGRect = .zero
    @State private var containerSize: CGSize = .zero
    
    // Minimum scale to ensure image covers the crop area
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    
    enum AspectRatio: String, CaseIterable {
        case original = "原有"
        case square = "正方形"
        case ratio3_2 = "3:2"
        case ratio5_3 = "5:3"
        case ratio4_3 = "4:3"
        case ratio5_4 = "5:4"
        case ratio7_5 = "7:5"
        case ratio16_9 = "16:9"
        
        var value: CGFloat? {
            switch self {
            case .original: return nil
            case .square: return 1.0
            case .ratio3_2: return 3.0/2.0
            case .ratio5_3: return 5.0/3.0
            case .ratio4_3: return 4.0/3.0
            case .ratio5_4: return 5.0/4.0
            case .ratio7_5: return 7.0/5.0
            case .ratio16_9: return 16.0/9.0
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "crop")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                    VStack(spacing: 4) {
                        Text("调整图片大小或位置")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("把想识别的内容放在屏幕中间")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Crop Area
                GeometryReader { geometry in
                    ZStack {
                        // Image
                        Image(uiImage: originalImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .rotationEffect(.degrees(rotation))
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale *= delta
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        withAnimation {
                                            if scale < minScale { scale = minScale }
                                            if scale > maxScale { scale = maxScale }
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        let translation = value.translation
                                        offset = CGSize(
                                            width: lastOffset.width + translation.width,
                                            height: lastOffset.height + translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        
                        // Crop Overlay (Mask)
                        Rectangle()
                            .fill(Color.black.opacity(0.5))
                            .mask(
                                ZStack {
                                    Rectangle()
                                    Rectangle()
                                        .frame(width: getCropSize(in: geometry.size).width,
                                               height: getCropSize(in: geometry.size).height)
                                        .blendMode(.destinationOut)
                                }
                            )
                            .allowsHitTesting(false)
                        
                        // Grid/Border
                        Rectangle()
                            .stroke(Color.white, lineWidth: 1)
                            .frame(width: getCropSize(in: geometry.size).width,
                                   height: getCropSize(in: geometry.size).height)
                            .allowsHitTesting(false)
                        
                        // Corner indicators
                        cropCorners(in: geometry.size)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .onAppear {
                        containerSize = geometry.size
                    }
                    .onChange(of: geometry.size) { newSize in
                        containerSize = newSize
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                Spacer()
                
                // Action Buttons & Toolbar Area
                VStack(spacing: 20) {
                    // Confirm/Cancel Buttons
                    VStack(spacing: 16) {
                        Button(action: cropImage) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.headline)
                                Text("确认选择")
                                    .font(.headline)
                            }
                            .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.9))
                            .frame(width: 160, height: 44)
                            .background(Color.white)
                            .clipShape(Capsule())
                        }
                        
                        Button("取消") {
                            dismiss()
                        }
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    }
                    .padding(.bottom, 10)
                    
                    // Toolbar
                    HStack(spacing: 0) {
                        // Rotate Left
                        Button(action: { rotate(-90) }) {
                            VStack {
                                Image(systemName: "rotate.left")
                                    .font(.title2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        // Reset
                        Button(action: reset) {
                            VStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        // Aspect Ratio
                        Button(action: { withAnimation { showingAspectRatioMenu.toggle() } }) {
                            VStack {
                                Image(systemName: "aspectratio")
                                    .font(.title2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        // Rotate Right
                        Button(action: { rotate(90) }) {
                            VStack {
                                Image(systemName: "rotate.right")
                                    .font(.title2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                }
            }
            
            // Custom Aspect Ratio Menu Overlay
            if showingAspectRatioMenu {
                Color.black.opacity(0.01) // Transparent catch-all for taps
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showingAspectRatioMenu = false }
                    }
                
                VStack(spacing: 1) {
                    ForEach(AspectRatio.allCases, id: \.self) { ratio in
                        Button(action: {
                            selectedAspectRatio = ratio
                            withAnimation { showingAspectRatioMenu = false }
                            reset()
                        }) {
                            Text(ratio.rawValue)
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(selectedAspectRatio == ratio ? Color.gray.opacity(0.2) : Color.white.opacity(0.9))
                        }
                    }
                }
                .frame(width: 140)
                .background(Color.white.opacity(0.9))
                .cornerRadius(16)
                .shadow(radius: 10)
                .padding(.bottom, 100)
                .position(x: UIScreen.main.bounds.width / 2 + 20, y: UIScreen.main.bounds.height - 180)
                .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
    }
    
    private func getCropSize(in size: CGSize) -> CGSize {
        let padding: CGFloat = 20
        let availableWidth = size.width - (padding * 2)
        let availableHeight = size.height - (padding * 2)
        
        var targetRatio: CGFloat
        if let ratio = selectedAspectRatio.value {
            targetRatio = ratio
        } else {
            // Original ratio
            targetRatio = originalImage.size.width / originalImage.size.height
            // Adjust for rotation
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
        
        return CGSize(width: width, height: height)
    }
    
    private func cropCorners(in size: CGSize) -> some View {
        let cropSize = getCropSize(in: size)
        let length: CGFloat = 20
        let thickness: CGFloat = 4
        
        return ZStack {
            // Top Left
            VStack(alignment: .leading, spacing: 0) {
                Rectangle().frame(width: length, height: thickness)
                Rectangle().frame(width: thickness, height: length)
            }
            .offset(x: -cropSize.width/2 + length/2 - thickness/2, y: -cropSize.height/2 + length/2 - thickness/2)
            
            // Top Right
            VStack(alignment: .trailing, spacing: 0) {
                Rectangle().frame(width: length, height: thickness)
                Rectangle().frame(width: thickness, height: length)
            }
            .offset(x: cropSize.width/2 - length/2 + thickness/2, y: -cropSize.height/2 + length/2 - thickness/2)
            
            // Bottom Left
            VStack(alignment: .leading, spacing: 0) {
                Rectangle().frame(width: thickness, height: length)
                Rectangle().frame(width: length, height: thickness)
            }
            .offset(x: -cropSize.width/2 + length/2 - thickness/2, y: cropSize.height/2 - length/2 + thickness/2)
            
            // Bottom Right
            VStack(alignment: .trailing, spacing: 0) {
                Rectangle().frame(width: thickness, height: length)
                Rectangle().frame(width: length, height: thickness)
            }
            .offset(x: cropSize.width/2 - length/2 + thickness/2, y: cropSize.height/2 - length/2 + thickness/2)
        }
        .foregroundColor(.white)
    }
    
    private func rotate(_ degrees: Double) {
        withAnimation {
            rotation += degrees
        }
    }
    
    private func reset() {
        withAnimation {
            scale = 1.0
            offset = .zero
            lastScale = 1.0
            lastOffset = .zero
            rotation = 0
        }
    }
    
    private func cropImage() {
        // 1. Handle rotation
        guard let rotatedImage = originalImage.rotated(by: Measurement(value: rotation, unit: .degrees)) else {
            onCrop(originalImage)
            dismiss()
            return
        }
        
        // 2. Calculate coordinates
        // Get the crop box size in view coordinates
        let cropBoxSize = getCropSize(in: containerSize)
        
        // Calculate the image's display size (fitted in container)
        // Note: The image inside the view is fitted to containerSize using aspectFit
        let widthRatio = containerSize.width / rotatedImage.size.width
        let heightRatio = containerSize.height / rotatedImage.size.height
        let baseScale = min(widthRatio, heightRatio)
        
        // Total scale applied to image
        let totalScale = baseScale * scale
        
        // Calculate the center of the crop box relative to the image center in view coordinates
        // Visual center of image is moved by `offset`
        // Visual center of crop box is at (0,0) (relative to container center)
        // Vector from ImageCenter to CropBoxCenter is -offset
        
        // Convert to image coordinates
        // Center of crop rect in image = ImageCenter + (-offset / totalScale)
        let imageCenter = CGPoint(x: rotatedImage.size.width / 2, y: rotatedImage.size.height / 2)
        let cropCenterInImage = CGPoint(
            x: imageCenter.x - (offset.width / totalScale),
            y: imageCenter.y - (offset.height / totalScale)
        )
        
        let cropWidthInImage = cropBoxSize.width / totalScale
        let cropHeightInImage = cropBoxSize.height / totalScale
        
        let cropRect = CGRect(
            x: cropCenterInImage.x - cropWidthInImage / 2,
            y: cropCenterInImage.y - cropHeightInImage / 2,
            width: cropWidthInImage,
            height: cropHeightInImage
        )
        
        // 3. Crop
        if let cgImage = rotatedImage.cgImage?.cropping(to: cropRect) {
            let croppedUIImage = UIImage(cgImage: cgImage, scale: originalImage.scale, orientation: .up)
            onCrop(croppedUIImage)
        } else {
            onCrop(rotatedImage)
        }
        
        dismiss()
    }
    
    private func cropImageInternal() -> UIImage {
        // Legacy, unused now
        return originalImage
    }
}

// Helper for rotation
extension UIImage {
    func rotated(by angle: Measurement<UnitAngle>) -> UIImage? {
        let radians = CGFloat(angle.converted(to: .radians).value)
        
        var newSize = CGRect(origin: .zero, size: self.size)
            .applying(CGAffineTransform(rotationAngle: radians)).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: radians)
        
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}
