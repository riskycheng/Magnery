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
    private let fetchCooldown: TimeInterval = 10.0 // Increased cooldown
    private let manifestCacheKey = "CommunityManifestCache"
    private let magnetsCacheFile = "cached_community_magnets.json"
    
    init() {
        loadFromCache()
    }
    
    private func loadFromCache() {
        let fileManager = FileManager.default
        guard let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let fileURL = cacheDir.appendingPathComponent(magnetsCacheFile)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let cached = try decoder.decode([CommunityMagnet].self, from: data)
                self.popularMagnets = cached
            } catch {
                // Silent fail for cache loading
            }
        }
    }
    
    private func saveToCache(_ magnets: [CommunityMagnet]) {
        let fileManager = FileManager.default
        guard let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let fileURL = cacheDir.appendingPathComponent(magnetsCacheFile)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(magnets)
            try data.write(to: fileURL)
        } catch {
            // Silent fail for cache saving
        }
    }

    private class FetchState {
        var items: [CommunityMagnet] = []
        let lock = NSLock()
    }
    
    func fetchCommunityContent(retryCount: Int = 0) {
        // Prevent redundant fetches
        if retryCount == 0 {
            if let last = lastFetchTime, Date().timeIntervalSince(last) < fetchCooldown && !popularMagnets.isEmpty {
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
            self.errorMessage = "无效的 URL"
            self.isLoading = false
            return
        }
        
        var request = URLRequest(url: manifestURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                let nsError = error as NSError
                // Standard retry logic for network issues
                if retryCount < 2 && (nsError.code == -1003 || nsError.code == -1001 || nsError.code == -1004) {
                    let delay = Double(retryCount + 1) * 1.5
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self?.fetchCommunityContent(retryCount: retryCount + 1)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self?.errorMessage = "网络连接失败"
                    self?.isLoading = false
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                DispatchQueue.main.async {
                    self?.errorMessage = "服务器错误: \(httpResponse.statusCode)"
                    self?.isLoading = false
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self?.errorMessage = "无数据返回"
                    self?.isLoading = false
                }
                return
            }
            
            // Compare with cached manifest content to avoid redownloading individual items
            if let jsonString = String(data: data, encoding: .utf8) {
                let cachedManifest = UserDefaults.standard.string(forKey: self?.manifestCacheKey ?? "")
                if cachedManifest == jsonString && !(self?.popularMagnets.isEmpty ?? true) {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                    }
                    return
                }
                UserDefaults.standard.set(jsonString, forKey: self?.manifestCacheKey ?? "")
            }
            
            do {
                let manifest = try JSONDecoder().decode(CommunityManifest.self, from: data)
                self?.fetchIndividualMagnets(names: manifest.items)
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = "数据处理失败"
                    self?.isLoading = false
                }
            }
        }
        task.resume()
    }
    
    private func fetchIndividualMagnets(names: [String]) {
        let group = DispatchGroup()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Use a thread-safe way to collect items
        let state = FetchState()
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpMaximumConnectionsPerHost = 4
        let session = URLSession(configuration: config)
        
        // Process in small batches
        let batchSize = 3
        let batches = stride(from: 0, to: names.count, by: batchSize).map {
            Array(names[$0..<min($0 + batchSize, names.count)])
        }
        
        func processBatch(index: Int) {
            guard index < batches.count else {
                group.notify(queue: .main) { [weak self] in
                    state.lock.lock()
                    let finalItems = state.items.sorted(by: { $0.date > $1.date })
                    state.lock.unlock()
                    
                    self?.popularMagnets = finalItems
                    self?.saveToCache(finalItems)
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
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    processBatch(index: index + 1)
                }
            }
        }
        
        processBatch(index: 0)
    }
    
    private func fetchSingleMagnet(name: String, session: URLSession, decoder: JSONDecoder, group: DispatchGroup, state: FetchState, retryCount: Int = 0, completion: @escaping () -> Void) {
        guard let url = URL(string: CommunityConfig.baseURL + name) else {
            group.leave()
            completion()
            return
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        
        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                let nsError = error as NSError
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
                state.lock.lock()
                state.items.append(item)
                state.lock.unlock()
            } catch {
                // Silent decoding error
            }
        }.resume()
    }
}
