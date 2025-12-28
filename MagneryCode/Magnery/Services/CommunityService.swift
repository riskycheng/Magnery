import Foundation
import Combine

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
    let date: Date
    
    var imageURL: URL? {
        URL(string: "https://gitee.com/riskycheng/magnery-res/raw/master/\(imageName)")
    }
    
    var gifURL: URL? {
        guard let gifName = gifName else { return nil }
        return URL(string: "https://gitee.com/riskycheng/magnery-res/raw/master/\(gifName)")
    }
}

struct CommunityManifest: Codable {
    let items: [String]
}

class CommunityService: ObservableObject {
    @Published var popularMagnets: [CommunityMagnet] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL = "https://gitee.com/riskycheng/magnery-res/raw/master/"
    
    func fetchCommunityContent() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        guard let manifestURL = URL(string: baseURL + "manifest.json") else {
            print("❌ [CommunityService] Invalid manifest URL")
            self.errorMessage = "无效的 URL"
            self.isLoading = false
            return
        }
        
        print("🌐 [CommunityService] Fetching manifest from: \(manifestURL.absoluteString)")
        
        URLSession.shared.dataTask(with: manifestURL) { [weak self] data, response, error in
            if let error = error {
                print("❌ [CommunityService] Manifest fetch error: \(error.localizedDescription)")
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
        }.resume()
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
        
        for name in names {
            group.enter()
            guard let url = URL(string: baseURL + name) else {
                print("⚠️ [CommunityService] Invalid URL for item: \(name)")
                group.leave()
                continue
            }
            
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
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
