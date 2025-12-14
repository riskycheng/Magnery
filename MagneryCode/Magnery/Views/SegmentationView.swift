import SwiftUI
import CoreImage.CIFilterBuiltins

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
    @State private var backgroundBlur: CGFloat = 0
    @State private var showBorder = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGray4)
                .ignoresSafeArea()
            
            VStack {
                Text(dateString)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                Spacer()
                
                ZStack {
                    if !isProcessing {
                        Image(uiImage: originalImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .blur(radius: backgroundBlur)
                            .frame(maxHeight: UIScreen.main.bounds.height * 0.65)
                            .padding()
                    }
                    
                    if isProcessing {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("正在分割背景...")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    } else if let image = segmentedImage {
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
                                .padding(40)
                            
                            if showBorder, let outline = outlineImage {
                                FlowingOutlineView(outlineImage: outline)
                                    .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
                                    .padding(40)
                            }
                        }
                        .opacity(showBorder ? 1 : 0)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 60) {
                    Button(action: {
                        processImage()
                    }) {
                        Circle()
                            .fill(Color.gray.opacity(0.8))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "arrow.clockwise")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            )
                    }
                    .disabled(isProcessing)
                    
                    Button(action: {
                        if segmentedImage != nil {
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
                    .disabled(isProcessing || segmentedImage == nil)
                    
                    Button(action: {
                        dismiss()
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
            }
        }
        .onAppear {
            processImage()
        }
        .fullScreenCover(isPresented: $showingAddView) {
            if let image = segmentedImage {
                let squareImage = ImageOutlineHelper.padToSquare(image: image) ?? image
                AddMagnetView(image: squareImage)
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
        backgroundBlur = 0
        showBorder = false
        
        VisionService.shared.removeBackground(from: originalImage) { result in
            DispatchQueue.main.async {
                if let result = result {
                    // Calculate dynamic offset and linewidth
                    let displayHeight = UIScreen.main.bounds.height * 0.5
                    let scaleFactor = result.image.size.height / displayHeight
                    
                    let offset = 10.0 * scaleFactor
                    let lineWidth = 4.0 * scaleFactor
                    
                    // Pad the image to make room for the external contour
                    // Padding needs to cover offset + linewidth on all sides
                    let padding = offset + lineWidth + 20.0
                    
                    if let paddedImage = ImageOutlineHelper.addPadding(to: result.image, amount: padding) {
                        self.segmentedImage = paddedImage
                        self.outlineImage = ImageOutlineHelper.createOutline(from: paddedImage, lineWidth: lineWidth, offset: offset)
                    } else {
                        self.segmentedImage = result.image
                        self.outlineImage = ImageOutlineHelper.createOutline(from: result.image, lineWidth: lineWidth, offset: offset)
                    }
                    
                    withAnimation(.easeInOut(duration: 1.0)) {
                        self.backgroundBlur = 20
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.showBorder = true
                        }
                        self.isProcessing = false
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
