import UIKit
import Vision
import CoreImage

struct SegmentationResult {
    let image: UIImage
    let contourPath: CGPath?
}

class VisionService {
    static let shared = VisionService()
    
    private init() {}
    
    func removeBackground(from image: UIImage, completion: @escaping (SegmentationResult?) -> Void) {
        print("[VisionService] 开始背景分割处理...")
        print("[VisionService] 原始图片尺寸: \(image.size), 方向: \(image.imageOrientation.rawValue)")
        
        guard let cgImage = image.cgImage else {
            print("[VisionService] ❌ 无法获取 CGImage")
            completion(nil)
            return
        }
        
        let request = VNGenerateForegroundInstanceMaskRequest { request, error in
            guard error == nil else {
                print("[VisionService] ❌ Vision 错误: \(error!.localizedDescription)")
                completion(nil)
                return
            }
            
            print("[VisionService] ✓ Vision 请求完成")
            
            guard let result = request.results?.first as? VNInstanceMaskObservation else {
                print("[VisionService] ❌ 未检测到前景对象")
                completion(nil)
                return
            }
            
            print("[VisionService] ✓ 检测到 \(result.allInstances.count) 个前景对象")
            
            do {
                let maskedImage = try result.generateMaskedImage(
                    ofInstances: result.allInstances,
                    from: VNImageRequestHandler(cgImage: cgImage),
                    croppedToInstancesExtent: true
                )
                
                print("[VisionService] ✓ 生成蒙版图像成功")
                
                let ciImage = CIImage(cvPixelBuffer: maskedImage)
                let context = CIContext()
                
                if let outputCGImage = context.createCGImage(ciImage, from: ciImage.extent) {
                    let outputImage = UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
                    print("[VisionService] ✓ 分割完成，输出图片尺寸: \(outputImage.size)")
                    
                    let contourPath = self.extractContour(from: outputImage)
                    print("[VisionService] ✓ 提取轮廓路径完成")
                    
                    let result = SegmentationResult(image: outputImage, contourPath: contourPath)
                    completion(result)
                } else {
                    print("[VisionService] ❌ 无法创建输出图像")
                    completion(nil)
                }
            } catch {
                print("[VisionService] ❌ 生成蒙版图像失败: \(error)")
                completion(nil)
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            print("[VisionService] 开始执行 Vision 请求...")
            do {
                try handler.perform([request])
            } catch {
                print("[VisionService] ❌ 执行 Vision 请求失败: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    private func extractContour(from image: UIImage) -> CGPath? {
        // Use Core Image to extract alpha channel and find edges
        guard let cgImage = image.cgImage else {
            print("[VisionService] ❌ 无法获取 CGImage")
            return nil
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // Extract alpha channel
        guard let alphaFilter = CIFilter(name: "CIMaskToAlpha") else {
            print("[VisionService] ❌ 无法创建 alpha 提取滤镜")
            return createSimpleBoundingBox(for: cgImage)
        }
        
        alphaFilter.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let alphaImage = alphaFilter.outputImage else {
            print("[VisionService] ❌ alpha 提取失败")
            return createSimpleBoundingBox(for: cgImage)
        }
        
        // Apply morphological gradient to find edges
        guard let morphFilter = CIFilter(name: "CIMorphologyGradient") else {
            print("[VisionService] ❌ 无法创建形态学滤镜")
            return createSimpleBoundingBox(for: cgImage)
        }
        
        morphFilter.setValue(alphaImage, forKey: kCIInputImageKey)
        morphFilter.setValue(2.0, forKey: kCIInputRadiusKey)
        
        guard let edgeImage = morphFilter.outputImage else {
            print("[VisionService] ❌ 边缘检测失败")
            return createSimpleBoundingBox(for: cgImage)
        }
        
        // Convert to bitmap
        let context = CIContext()
        let width = cgImage.width
        let height = cgImage.height
        
        guard let edgeCGImage = context.createCGImage(edgeImage, from: edgeImage.extent) else {
            print("[VisionService] ❌ 无法创建边缘图像")
            return createSimpleBoundingBox(for: cgImage)
        }
        
        // Read edge pixels
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bytesPerPixel = 1
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height)
        
        guard let bitmapContext = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            print("[VisionService] ❌ 无法创建位图上下文")
            return createSimpleBoundingBox(for: cgImage)
        }
        
        bitmapContext.draw(edgeCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let buffer = pixelData
        
        // Find edge pixels from morphological gradient
        var boundaryPixels: [(x: Int, y: Int)] = []
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * width + x
                let intensity = buffer[offset]
                
                if intensity > 30 {
                    boundaryPixels.append((x, y))
                }
            }
        }
        
        guard !boundaryPixels.isEmpty else {
            print("[VisionService] ❌ 未找到边界像素")
            return nil
        }
        
        print("[VisionService] ✓ 找到 \(boundaryPixels.count) 个边界像素")
        
        // Convert to set for fast lookup
        var boundarySet = Set(boundaryPixels.map { "\($0.x),\($0.y)" })
        
        // Find starting point (leftmost-topmost)
        guard let start = boundaryPixels.min(by: { p1, p2 in
            if p1.x == p2.x { return p1.y < p2.y }
            return p1.x < p2.x
        }) else { return nil }
        
        // Trace contour using 8-connectivity
        var orderedPixels: [(x: Int, y: Int)] = []
        var current = start
        var visited = Set<String>()
        
        let directions = [
            (1, 0), (1, 1), (0, 1), (-1, 1),
            (-1, 0), (-1, -1), (0, -1), (1, -1)
        ]
        
        var lastDir = 0
        
        repeat {
            let key = "\(current.x),\(current.y)"
            if visited.contains(key) && orderedPixels.count > 10 {
                break
            }
            
            orderedPixels.append(current)
            visited.insert(key)
            boundarySet.remove(key)
            
            // Look for next boundary pixel in 8-neighborhood
            var found = false
            for i in 0..<8 {
                let dir = (lastDir + i + 6) % 8 // Start from slightly behind
                let (dx, dy) = directions[dir]
                let next = (x: current.x + dx, y: current.y + dy)
                let nextKey = "\(next.x),\(next.y)"
                
                if boundarySet.contains(nextKey) {
                    current = next
                    lastDir = dir
                    found = true
                    break
                }
            }
            
            if !found {
                // Try to find any unvisited boundary pixel nearby
                if let nearby = boundaryPixels.first(where: {
                    let key = "\($0.x),\($0.y)"
                    return !visited.contains(key) &&
                           abs($0.x - current.x) <= 2 &&
                           abs($0.y - current.y) <= 2
                }) {
                    current = nearby
                } else {
                    break
                }
            }
            
        } while orderedPixels.count < boundaryPixels.count && orderedPixels.count < 10000
        
        print("[VisionService] ✓ 追踪到 \(orderedPixels.count) 个有序边界点")
        
        // Sample points to reduce complexity
        let targetPoints = 120
        let step = max(1, orderedPixels.count / targetPoints)
        let sampledPixels = stride(from: 0, to: orderedPixels.count, by: step).map { orderedPixels[$0] }
        
        // Create path with normalized coordinates
        let path = CGMutablePath()
        
        if sampledPixels.count > 2 {
            let firstPoint = CGPoint(
                x: CGFloat(sampledPixels[0].x) / CGFloat(width),
                y: CGFloat(sampledPixels[0].y) / CGFloat(height)
            )
            path.move(to: firstPoint)
            
            // Use cubic Bezier curves for very smooth path
            for i in 0..<sampledPixels.count {
                let current = sampledPixels[i]
                let next = sampledPixels[(i + 1) % sampledPixels.count]
                let nextNext = sampledPixels[(i + 2) % sampledPixels.count]
                
                let p0 = CGPoint(
                    x: CGFloat(current.x) / CGFloat(width),
                    y: CGFloat(current.y) / CGFloat(height)
                )
                let p1 = CGPoint(
                    x: CGFloat(next.x) / CGFloat(width),
                    y: CGFloat(next.y) / CGFloat(height)
                )
                let p2 = CGPoint(
                    x: CGFloat(nextNext.x) / CGFloat(width),
                    y: CGFloat(nextNext.y) / CGFloat(height)
                )
                
                // Calculate control points for smooth curve
                let cp1 = CGPoint(
                    x: p0.x + (p1.x - p0.x) * 0.5,
                    y: p0.y + (p1.y - p0.y) * 0.5
                )
                let cp2 = CGPoint(
                    x: p1.x - (p2.x - p1.x) * 0.5,
                    y: p1.y - (p2.y - p1.y) * 0.5
                )
                
                path.addCurve(to: p1, control1: cp1, control2: cp2)
            }
            
            path.closeSubpath()
        }
        
        print("[VisionService] ✓ 轮廓采样: \(sampledPixels.count) 个点")
        
        return path
    }
    
    private func createSimpleBoundingBox(for cgImage: CGImage) -> CGPath {
        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: 1, height: 1))
        return path
    }
}
