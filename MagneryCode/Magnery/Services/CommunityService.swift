import Foundation
import Combine

struct CommunityConfig {
    static let baseURL = "https://magnery-1259559729.cos.ap-shanghai.myqcloud.com/magnery_resources/"
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
    
    private var lastFetchTime: Date?
    private let fetchCooldown: TimeInterval = 5.0 // Don't refetch within 5 seconds
    
    private class FetchState {
        var items: [CommunityMagnet] = []
        let lock = NSLock()
    }
    
    func fetchCommunityContent(retryCount: Int = 0) {
        // Prevent redundant fetches
        if retryCount == 0 {
            if let last = lastFetchTime, Date().timeIntervalSince(last) < fetchCooldown && !popularMagnets.isEmpty {
                print("ℹ️ [CommunityService] Skipping fetch due to cooldown")
                return
            }
        }
        
        guard !isLoading || retryCount > 0 else { return }
        
        if retryCount == 0 {
            isLoading = true
            errorMessage = nil
            lastFetchTime = Date()
        }
        
        let urlString = CommunityConfig.baseURL + "manifest.json"
        guard let manifestURL = URL(string: urlString) else {
            print("❌ [CommunityService] Invalid manifest URL")
            self.errorMessage = "无效的 URL"
            self.isLoading = false
            return
        }
        
        print("🌐 [CommunityService] Fetching manifest from: \(manifestURL.absoluteString) (Attempt \(retryCount + 1))")
        
        var request = URLRequest(url: manifestURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            print("📡 [CommunityService] Manifest task completed. Error: \(error?.localizedDescription ?? "none")")
            
            if let error = error {
                let nsError = error as NSError
                print("❌ [CommunityService] Manifest fetch error: \(error.localizedDescription) (code: \(nsError.code))")
                
                // Standard retry logic for the current URL
                if retryCount < 2 && (nsError.code == -1003 || nsError.code == -1001 || nsError.code == -1004) {
                    let delay = Double(retryCount + 1) * 1.0
                    print("🔄 [CommunityService] Retrying current URL in \(delay)s...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self?.fetchCommunityContent(retryCount: retryCount + 1)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self?.errorMessage = "加载失败: \(error.localizedDescription)"
                    self?.isLoading = false
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [CommunityService] Manifest response code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    DispatchQueue.main.async {
                        self?.errorMessage = "服务器错误: \(httpResponse.statusCode)"
                        self?.isLoading = false
                    }
                    return
                }
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
                print("✅ [CommunityService] Manifest decoded from \(CommunityConfig.baseURL), found \(manifest.items.count) items")
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
        let state = FetchState()
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpMaximumConnectionsPerHost = 4 // Limit concurrency for poor networks
        let session = URLSession(configuration: config)
        
        // Process in small batches to avoid overwhelming the network
        let batchSize = 3
        let batches = stride(from: 0, to: names.count, by: batchSize).map {
            Array(names[$0..<min($0 + batchSize, names.count)])
        }
        
        func processBatch(index: Int) {
            guard index < batches.count else {
                group.notify(queue: .main) { [weak self] in
                    print("🏁 [CommunityService] Finished fetching all items")
                    self?.isLoading = false
                }
                return
            }
            
            let batch = batches[index]
            let batchGroup = DispatchGroup()
            
            for name in batch {
                batchGroup.enter()
                group.enter()
                self.fetchSingleMagnet(name: name, session: session, decoder: decoder, group: group, state: state) {
                    batchGroup.leave()
                }
            }
            
            batchGroup.notify(queue: .global()) {
                // Small delay between batches to let the network breathe
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                    processBatch(index: index + 1)
                }
            }
        }
        
        processBatch(index: 0)
    }
    
    private func fetchSingleMagnet(name: String, session: URLSession, decoder: JSONDecoder, group: DispatchGroup, state: FetchState, retryCount: Int = 0, completion: @escaping () -> Void) {
        guard let url = URL(string: CommunityConfig.baseURL + name) else {
            print("⚠️ [CommunityService] Invalid URL for item: \(name)")
            group.leave()
            completion()
            return
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                let nsError = error as NSError
                print("❌ [CommunityService] Error fetching \(name): \(error.localizedDescription) (code: \(nsError.code))")
                
                if retryCount < 2 && (nsError.code == -1003 || nsError.code == -1001 || nsError.code == -1004) {
                    let delay = Double(retryCount + 1) * 0.5
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self?.fetchSingleMagnet(name: name, session: session, decoder: decoder, group: group, state: state, retryCount: retryCount + 1, completion: completion)
                    }
                    return
                }
                
                group.leave()
                completion()
                return
            }
            
            defer { 
                group.leave()
                completion()
            }
            guard let data = data else { return }
            
            do {
                let item = try decoder.decode(CommunityMagnet.self, from: data)
                print("✅ [CommunityService] Decoded item: \(item.name)")
                
                state.lock.lock()
                state.items.append(item)
                let currentItems = state.items.sorted(by: { $0.date > $1.date })
                state.lock.unlock()
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    if self?.popularMagnets.count != currentItems.count {
                        self?.popularMagnets = currentItems
                    }
                }
            } catch {
                print("❌ [CommunityService] Decoding error for \(name): \(error)")
            }
        }.resume()
    }
}
