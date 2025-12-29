import SwiftUI

struct CachedAsyncImage: View {
    let url: URL?
    @StateObject private var downloadManager = DownloadManager()
    @State private var image: UIImage?
    @State private var hasError = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
            } else if hasError {
                ZStack {
                    Color.gray.opacity(0.1)
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange.opacity(0.6))
                        Text("加载失败")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            } else if downloadManager.isDownloading {
                ZStack {
                    Color.gray.opacity(0.1)
                    
                    VStack(spacing: 8) {
                        ProgressView(value: downloadManager.progress)
                            .progressViewStyle(.linear)
                            .frame(width: 100)
                        
                        Text("\(Int(downloadManager.progress * 100))%")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                ZStack {
                    Color.gray.opacity(0.1)
                    Image(systemName: "photo")
                        .foregroundColor(.gray.opacity(0.3))
                }
                .onAppear {
                    loadImage()
                }
                .onChange(of: url) { _ in
                    loadImage()
                }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        // Check cache - use a sanitized version of the URL as the key
        // Swift's .hash is not stable across launches, so we sanitize the string
        let cacheKey = url.absoluteString.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ImageCache")
        
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        
        let cachedFileURL = cacheDir.appendingPathComponent(cacheKey)
        
        if let cachedData = try? Data(contentsOf: cachedFileURL), let cachedImage = UIImage(data: cachedData) {
            print("📦 [CachedAsyncImage] Using cache for: \(url.lastPathComponent)")
            self.image = cachedImage
            self.hasError = false
            return
        }
        
        print("🌐 [CachedAsyncImage] Downloading: \(url.absoluteString)")
        // Download
        Task {
            do {
                let tempURL = try await downloadManager.download(url: url, to: cachedFileURL)
                if let data = try? Data(contentsOf: tempURL), let downloadedImage = UIImage(data: data) {
                    // Save to cache
                    try? data.write(to: cachedFileURL)
                    
                    DispatchQueue.main.async {
                        self.image = downloadedImage
                        self.hasError = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.hasError = true
                    }
                }
            } catch {
                print("❌ [CachedAsyncImage] Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.hasError = true
                }
            }
        }
    }
}
