import UIKit
import ImageIO
import MobileCoreServices
import UniformTypeIdentifiers

class GIFService {
    static let shared = GIFService()
    
    private init() {}
    
    func createGIF(from images: [UIImage], frameDelay: Double = 0.1, completion: @escaping (URL?) -> Void) {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = UUID().uuidString + ".gif"
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.gif.identifier as CFString, images.count, nil) else {
            completion(nil)
            return
        }
        
        let fileProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0 // 0 means infinite loop
            ]
        ]
        
        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay
            ]
        ]
        
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        
        for image in images {
            if let cgImage = image.cgImage {
                CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
            }
        }
        
        if CGImageDestinationFinalize(destination) {
            completion(fileURL)
        } else {
            completion(nil)
        }
    }
}
