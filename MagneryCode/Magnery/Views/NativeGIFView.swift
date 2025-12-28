import SwiftUI
import ImageIO

struct NativeGIFView: View {
    let url: URL
    @State private var currentFrame: UIImage? = nil
    @State private var frameIndex = 0
    @State private var frames: [CGImage] = []
    @State private var delays: [Double] = []
    @State private var timer: Timer? = nil
    
    var body: some View {
        Group {
            if let image = currentFrame {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .shimmering()
            }
        }
        .onAppear {
            loadGIF()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func loadGIF() {
        let isLocal = url.isFileURL
        
        if isLocal {
            DispatchQueue.global(qos: .userInitiated).async {
                if let data = try? Data(contentsOf: url) {
                    self.prepareFrames(from: data)
                }
            }
        } else {
            URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data, error == nil else { return }
                self.prepareFrames(from: data)
            }.resume()
        }
    }
    
    private func prepareFrames(from data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
        let count = CGImageSourceGetCount(source)
        
        var tempFrames: [CGImage] = []
        var tempDelays: [Double] = []
        
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                tempFrames.append(cgImage)
            }
            
            let delay = NativeGIFView.delayForImageAtIndex(i, source: source)
            tempDelays.append(delay)
        }
        
        DispatchQueue.main.async {
            self.frames = tempFrames
            self.delays = tempDelays
            self.startAnimation()
        }
    }
    
    private func startAnimation() {
        guard !frames.isEmpty else { return }
        stopAnimation()
        
        animateNextFrame()
    }
    
    private func animateNextFrame() {
        guard !frames.isEmpty else { return }
        
        let index = frameIndex % frames.count
        currentFrame = UIImage(cgImage: frames[index])
        let delay = delays[index]
        
        frameIndex += 1
        
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            self.animateNextFrame()
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
    
    static func delayForImageAtIndex(_ index: Int, source: CGImageSource) -> Double {
        var delay = 0.1
        let cfProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
        let properties = cfProperties as? [String: Any]
        let gifProperties = properties?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
        
        var delayObject = gifProperties?[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
        if delayObject == nil {
            delayObject = gifProperties?[kCGImagePropertyGIFDelayTime as String] as? Double
        }
        
        if let delayObject = delayObject, delayObject > 0 {
            delay = delayObject
        }
        return delay
    }
}

