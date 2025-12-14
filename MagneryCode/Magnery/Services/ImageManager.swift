import UIKit
import SwiftUI

class ImageManager {
    static let shared = ImageManager()
    
    private init() {}
    
    func saveImage(_ image: UIImage) -> String? {
        guard let data = image.pngData() else { return nil }
        
        let filename = UUID().uuidString + ".png"
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        
        do {
            try data.write(to: url)
            return filename
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    func loadImage(filename: String) -> UIImage? {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
    
    func deleteImage(filename: String) {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
