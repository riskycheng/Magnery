import SwiftUI

@MainActor
struct CachedAsyncImage: View {
    let url: URL?
    let fallbackURLs: [URL]
    @StateObject private var downloadManager = DownloadManager()
    @State private var image: UIImage?
    @State private var hasError = false
    @State private var currentURLIndex = -1 // -1 means primary URL, 0+ means fallback index
    
    init(url: URL?, fallbackURLs: [URL] = []) {
        self.url = url
        self.fallbackURLs = fallbackURLs
    }
    
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
                        
                        Button(action: {
                            hasError = false
                            currentURLIndex = -1
                            loadImage()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                        }
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
                    image = nil
                    hasError = false
                    currentURLIndex = -1
                    loadImage()
                }
            }
        }
    }
    
    private func loadImage() {
        let targetURL: URL?
        if currentURLIndex == -1 {
            targetURL = url
        } else if currentURLIndex < fallbackURLs.count {
            targetURL = fallbackURLs[currentURLIndex]
        } else {
            targetURL = nil
        }
        
        guard let activeURL = targetURL else {
            if currentURLIndex < fallbackURLs.count - 1 {
                currentURLIndex += 1
                loadImage()
            } else {
                self.hasError = true
            }
            return
        }
        
        print("🌐 [CachedAsyncImage] Trying URL (\(currentURLIndex == -1 ? "Primary" : "Fallback \(currentURLIndex)")): \(activeURL.absoluteString)")
        
        // Check cache - use a sanitized version of the URL as the key
        let cacheKey = activeURL.absoluteString.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ImageCache")
        
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        
        let cachedFileURL = cacheDir.appendingPathComponent(cacheKey)
        
        if let cachedData = try? Data(contentsOf: cachedFileURL), let cachedImage = UIImage(data: cachedData) {
            print("📦 [CachedAsyncImage] Using cache for: \(activeURL.lastPathComponent)")
            self.image = cachedImage
            self.hasError = false
            return
        } else if FileManager.default.fileExists(atPath: cachedFileURL.path) {
            // If file exists but UIImage failed, it's likely corrupt
            try? FileManager.default.removeItem(at: cachedFileURL)
        }
        
        print("🌐 [CachedAsyncImage] Downloading: \(activeURL.absoluteString)")
        // Download
        Task {
            do {
                let tempURL = try await downloadManager.download(url: activeURL, to: cachedFileURL)
                print("✅ [CachedAsyncImage] Download finished: \(activeURL.lastPathComponent)")
                
                if let data = try? Data(contentsOf: tempURL), let downloadedImage = UIImage(data: data) {
                    // Save to cache
                    try? data.write(to: cachedFileURL)
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempURL)
                    
                    self.image = downloadedImage
                    self.hasError = false
                } else {
                    print("❌ [CachedAsyncImage] Failed to create image from data: \(activeURL.lastPathComponent)")
                    try? FileManager.default.removeItem(at: tempURL)
                    tryNextURL()
                }
            } catch {
                print("❌ [CachedAsyncImage] Error: \(error.localizedDescription)")
                tryNextURL()
            }
        }
    }
    
    private func tryNextURL() {
        if currentURLIndex < fallbackURLs.count - 1 {
            currentURLIndex += 1
            loadImage()
        } else {
            self.hasError = true
        }
    }
}
