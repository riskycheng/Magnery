import UIKit
import SwiftUI

class ImageManager {
    static let shared = ImageManager()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100 // Limit cache to 100 images
    }
    
    func saveImage(_ image: UIImage) -> String? {
        guard let data = image.pngData() else { return nil }
        
        let filename = UUID().uuidString + ".png"
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        
        do {
            try data.write(to: url)
            cache.setObject(image, forKey: filename as NSString)
            return filename
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    func saveGIF(from url: URL) -> String? {
        let filename = UUID().uuidString + ".gif"
        let destinationURL = getDocumentsDirectory().appendingPathComponent(filename)
        
        do {
            try FileManager.default.moveItem(at: url, to: destinationURL)
            return filename
        } catch {
            print("Error saving GIF: \(error)")
            return nil
        }
    }
    
    func loadImage(filename: String) -> UIImage? {
        if let cached = cache.object(forKey: filename as NSString) {
            return cached
        }
        
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        
        if filename.lowercased().hasSuffix(".gif") {
            // For GIFs, we might want to return the first frame or a special animated image
            // For now, let's return the first frame as a placeholder
            if let data = try? Data(contentsOf: url),
               let source = CGImageSourceCreateWithData(data as CFData, nil),
               let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                let image = UIImage(cgImage: cgImage)
                cache.setObject(image, forKey: filename as NSString)
                return image
            }
        }
        
        if let image = UIImage(contentsOfFile: url.path) {
            cache.setObject(image, forKey: filename as NSString)
            return image
        }
        return nil
    }
    
    func getFileURL(for filename: String) -> URL {
        return getDocumentsDirectory().appendingPathComponent(filename)
    }

    
    func deleteImage(filename: String) {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        cache.removeObject(forKey: filename as NSString)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
