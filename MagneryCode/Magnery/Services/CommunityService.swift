import Foundation
import Combine

struct CommunityConfig {
    // Change this to switch between different hosting environments
    static let baseURL = "http://t81751iws.hn-bkt.clouddn.com/magnets_resources/"
    
    // Examples:
    // static let baseURL = "https://gitee.com/riskycheng/magnery-res/raw/master/"
    // static let baseURL = "https://riskycheng.gitee.io/magnery-res/" // Gitee Pages
}

struct CommunityMagnet: Identifiable, Codable {
    let id: String
    let name: String
    let userName: String
    let userAvatar: String
    let location: String
    let latitude: Double?
    let longitude: Double?
    let notes: String
    var likes: Int
    let imageName: String
    let gifName: String?
    let modelName: String?
    let date: Date
    
    var imageURL: URL? {
        let base = CommunityConfig.baseURL
        var name = imageName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Fallback: if imageName is empty but modelName exists, try using modelName with .jpg
        if name.isEmpty, let model = modelName?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty {
            let baseName = (model as NSString).deletingPathExtension
            name = baseName + ".jpg"
        }
        
        if name.isEmpty { return nil }
        
        let fullString = name.hasPrefix("http") ? name : base + name
        
        // Only encode if it's not already a valid URL
        if let url = URL(string: fullString) {
            return url
        }
        
        // If it fails, try encoding only the characters that are definitely illegal in a URL
        return URL(string: fullString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fullString)
    }
    
    var imageFallbackURLs: [URL] {
        let base = CommunityConfig.baseURL
        var urls: [URL] = []
        let extensions = ["jpg", "JPG", "png", "PNG", "jpeg", "JPEG"]
        
        // 1. Try variations of the imageName if it exists
        let name = imageName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            let baseName = (name as NSString).deletingPathExtension
            for ext in extensions {
                let fallbackURLString = base + baseName + "." + ext
                if let url = URL(string: fallbackURLString), url.absoluteString != imageURL?.absoluteString {
                    if !urls.contains(url) {
                        urls.append(url)
                    }
                }
            }
        }
        
        // 2. Try variations of the modelName
        if let model = modelName?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty {
            let baseName = (model as NSString).deletingPathExtension
            for ext in extensions {
                let fallbackURLString = base + baseName + "." + ext
                if let url = URL(string: fallbackURLString), url.absoluteString != imageURL?.absoluteString {
                    if !urls.contains(url) {
                        urls.append(url)
                    }
                }
            }
        }
        return urls
    }
    
    var gifURL: URL? {
        guard let gifName = gifName?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        let base = CommunityConfig.baseURL
        let fullString = gifName.hasPrefix("http") ? gifName : base + gifName
        
        if let url = URL(string: fullString) {
            return url
        }
        return URL(string: fullString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fullString)
    }

    var modelURL: URL? {
        guard let modelName = modelName?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        let base = CommunityConfig.baseURL
        let fullString = modelName.hasPrefix("http") ? modelName : base + modelName
        
        if let url = URL(string: fullString) {
            return url
        }
        return URL(string: fullString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fullString)
    }
    
    func toMagnetItem() -> MagnetItem {
        MagnetItem(
            id: UUID(),
            name: name,
            date: date,
            location: location,
            latitude: latitude,
            longitude: longitude,
            imagePath: imageURL?.absoluteString ?? "",
            gifPath: gifURL?.absoluteString,
            modelPath: modelURL?.absoluteString,
            notes: notes
        )
    }
}

struct CommunityManifest: Codable {
    let items: [String]
}

class CommunityService: ObservableObject {
    @Published var popularMagnets: [CommunityMagnet] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchCommunityContent() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        guard let manifestURL = URL(string: CommunityConfig.baseURL + "manifest.json") else {
            print("❌ [CommunityService] Invalid manifest URL")
            self.errorMessage = "无效的 URL"
            self.isLoading = false
            return
        }
        
        print("🌐 [CommunityService] Fetching manifest from: \(manifestURL.absoluteString)")
        
        var request = URLRequest(url: manifestURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
        // Use ephemeral session to avoid DNS/Cache issues
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ [CommunityService] Manifest fetch error: \(error.localizedDescription) (code: \((error as NSError).code))")
                
                DispatchQueue.main.async {
                    self?.errorMessage = "加载失败: \(error.localizedDescription)"
                    self?.isLoading = false
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [CommunityService] Manifest response code: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("❌ [CommunityService] No data received for manifest")
                DispatchQueue.main.async {
                    self?.errorMessage = "无数据返回"
                    self?.isLoading = false
                }
                return
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 [CommunityService] Manifest content: \(jsonString)")
            }
            
            do {
                let manifest = try JSONDecoder().decode(CommunityManifest.self, from: data)
                print("✅ [CommunityService] Manifest decoded, found \(manifest.items.count) items")
                self?.fetchIndividualMagnets(names: manifest.items)
            } catch {
                print("❌ [CommunityService] Manifest decoding error: \(error)")
                DispatchQueue.main.async {
                    self?.errorMessage = "解析清单失败"
                    self?.isLoading = false
                }
            }
        }
        print("🚀 [CommunityService] Task resumed")
        task.resume()
    }
    
    private func fetchIndividualMagnets(names: [String]) {
        let group = DispatchGroup()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        print("🔄 [CommunityService] Starting to fetch \(names.count) individual magnets")
        
        // Clear existing items for a fresh load
        DispatchQueue.main.async {
            self.popularMagnets = []
        }
        
        // Use a thread-safe way to collect items
        let queue = DispatchQueue(label: "com.magnery.community.fetch", attributes: .concurrent)
        var fetchedItems: [CommunityMagnet] = []
        let lock = NSLock()
        
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config)
        
        for name in names {
            group.enter()
            guard let url = URL(string: CommunityConfig.baseURL + name) else {
                print("⚠️ [CommunityService] Invalid URL for item: \(name)")
                group.leave()
                continue
            }
            
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            
            session.dataTask(with: request) { [weak self] data, response, error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ [CommunityService] Error fetching \(name): \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else { return }
                
                do {
                    let item = try decoder.decode(CommunityMagnet.self, from: data)
                    
                    lock.lock()
                    fetchedItems.append(item)
                    let currentItems = fetchedItems.sorted(by: { $0.date > $1.date })
                    lock.unlock()
                    
                    // Update UI on main thread with a small delay to batch updates
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if self?.popularMagnets.count != currentItems.count {
                            self?.popularMagnets = currentItems
                        }
                    }
                } catch {
                    print("❌ [CommunityService] Decoding error for \(name): \(error)")
                }
            }.resume()
        }
        
        group.notify(queue: .main) { [weak self] in
            print("🏁 [CommunityService] Finished fetching all items")
            self?.isLoading = false
        }
    }
}
