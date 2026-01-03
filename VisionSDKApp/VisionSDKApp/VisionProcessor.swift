import Foundation
import Vision
import AppKit
import CoreImage
import Combine

class VisionProcessor: ObservableObject {
    @Published var progress: Double = 0
    @Published var isProcessing: Bool = false
    @Published var statusMessage: String = "Ready"
    @Published var generate3D: Bool = false
    
    func processBatch(inputFolder: URL, outputFolder: URL) async {
        DispatchQueue.main.async {
            self.isProcessing = true
            self.progress = 0
            self.statusMessage = "Starting batch processing..."
        }
        
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: inputFolder, includingPropertiesForKeys: nil) else {
            DispatchQueue.main.async {
                self.statusMessage = "Error: Could not read input folder"
                self.isProcessing = false
            }
            return
        }
        
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "tiff"]
        let imageFiles = files.filter { imageExtensions.contains($0.pathExtension.lowercased()) }
        
        if imageFiles.isEmpty {
            DispatchQueue.main.async {
                self.statusMessage = "No images found in input folder"
                self.isProcessing = false
            }
            return
        }
        
        let total = Double(imageFiles.count)
        var completed = 0.0
        
        for fileURL in imageFiles {
            DispatchQueue.main.async {
                self.statusMessage = "Processing \(fileURL.lastPathComponent)..."
            }
            
            if let segmentedImage = await segmentImage(at: fileURL) {
                let normalizedImage = normalizeImage(segmentedImage)
                let baseName = fileURL.deletingPathExtension().lastPathComponent
                let outputURL = outputFolder.appendingPathComponent(baseName + ".png")
                saveImage(normalizedImage, to: outputURL)
                
                if generate3D {
                    await handle3DGeneration(image: normalizedImage, baseName: baseName, outputFolder: outputFolder)
                }
            }
            
            completed += 1
            DispatchQueue.main.async {
                self.progress = completed / total
            }
        }
        
        DispatchQueue.main.async {
            self.statusMessage = "Completed! Processed \(Int(total)) images."
            self.isProcessing = false
        }
    }
    
    private func segmentImage(at url: URL) async -> NSImage? {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            guard let result = request.results?.first as? VNInstanceMaskObservation else {
                return nil
            }
            
            let instancesToUse = selectSubjectInstances(from: result)
            let maskedPixelBuffer = try result.generateMaskedImage(
                ofInstances: instancesToUse,
                from: handler,
                croppedToInstancesExtent: true
            )
            
            let ciImage = CIImage(cvPixelBuffer: maskedPixelBuffer)
            let context = CIContext()
            
            guard let outputCGImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                return nil
            }
            
            return NSImage(cgImage: outputCGImage, size: NSSize(width: outputCGImage.width, height: outputCGImage.height))
            
        } catch {
            print("Segmentation error for \(url.lastPathComponent): \(error)")
            return nil
        }
    }
    
    private func selectSubjectInstances(from observation: VNInstanceMaskObservation) -> IndexSet {
        let allInstances = observation.allInstances
        if allInstances.count <= 1 { return allInstances }
        
        let mask = observation.instanceMask
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(mask) else {
            return allInstances
        }
        
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        
        var minXs = [Int](repeating: Int.max, count: 256)
        var maxXs = [Int](repeating: Int.min, count: 256)
        var minYs = [Int](repeating: Int.max, count: 256)
        var maxYs = [Int](repeating: Int.min, count: 256)
        var presentIds = Set<Int>()
        
        let step = 5
        for y in stride(from: 0, to: height, by: step) {
            let row = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in stride(from: 0, to: width, by: step) {
                let id = Int(row[x])
                if id == 0 { continue }
                
                if minXs[id] > x { minXs[id] = x }
                if maxXs[id] < x { maxXs[id] = x }
                if minYs[id] > y { minYs[id] = y }
                if maxYs[id] < y { maxYs[id] = y }
                presentIds.insert(id)
            }
        }
        
        let centerX = Double(width) / 2.0
        let centerY = Double(height) / 2.0
        
        var bestId: Int?
        var minDistance: Double = .greatestFiniteMagnitude
        
        for id in presentIds {
            if !allInstances.contains(id) { continue }
            
            let boxCenterX = Double(minXs[id] + maxXs[id]) / 2.0
            let boxCenterY = Double(minYs[id] + maxYs[id]) / 2.0
            
            let distSq = pow(boxCenterX - centerX, 2) + pow(boxCenterY - centerY, 2)
            
            if distSq < minDistance {
                minDistance = distSq
                bestId = id
            }
        }
        
        if let best = bestId {
            return IndexSet(integer: best)
        }
        
        return allInstances
    }
    
    private func handle3DGeneration(image: NSImage, baseName: String, outputFolder: URL) async {
        DispatchQueue.main.async {
            self.statusMessage = "Generating 3D model for \(baseName)..."
        }
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return
        }
        
        let base64 = pngData.base64EncodedString()
        
        do {
            let jobId = try await Tencent3DService.shared.submitJob(imageBase64: base64)
            let usdzUrlString = try await Tencent3DService.shared.pollJobStatus(jobId: jobId)
            
            if let usdzUrl = URL(string: usdzUrlString) {
                let (data, _) = try await URLSession.shared.data(from: usdzUrl)
                let destinationURL = outputFolder.appendingPathComponent(baseName + ".usdz")
                try data.write(to: destinationURL)
                print("Successfully saved 3D model to \(destinationURL.path)")
            }
        } catch {
            print("3D Generation error for \(baseName): \(error)")
            DispatchQueue.main.async {
                self.statusMessage = "3D Error for \(baseName): \(error.localizedDescription)"
            }
        }
    }
    
    private func normalizeImage(_ image: NSImage, targetSize: NSSize = NSSize(width: 1000, height: 1000)) -> NSImage {
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        
        // Clear background (transparent)
        NSColor.clear.set()
        NSRect(origin: .zero, size: targetSize).fill()
        
        // Calculate scaling to fit targetSize while maintaining aspect ratio
        // We use 95% of the target size to leave a small margin
        let marginScale: CGFloat = 0.95
        let widthRatio = (targetSize.width * marginScale) / image.size.width
        let heightRatio = (targetSize.height * marginScale) / image.size.height
        let scale = min(widthRatio, heightRatio)
        
        let drawSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let drawRect = NSRect(
            x: (targetSize.width - drawSize.width) / 2,
            y: (targetSize.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        
        image.draw(in: drawRect, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
        
        newImage.unlockFocus()
        return newImage
    }
    
    private func saveImage(_ image: NSImage, to url: URL) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return
        }
        
        try? pngData.write(to: url)
    }
}
