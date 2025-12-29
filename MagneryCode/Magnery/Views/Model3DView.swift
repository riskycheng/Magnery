import SwiftUI
import SceneKit
import ModelIO
import SceneKit.ModelIO

struct Model3DView: View {
    let url: URL
    @State private var scene: SCNScene?
    @State private var isLoading = true
    @State private var error: String?
    @StateObject private var downloadManager = DownloadManager()

    var body: some View {
        ZStack {
            if let scene = scene {
                SceneView(
                    scene: scene,
                    options: [.autoenablesDefaultLighting, .allowsCameraControl]
                )
                .frame(maxWidth: .infinity)
                .frame(height: 350)
                .background(Color.clear)
            } else if isLoading {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: downloadManager.progress)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear, value: downloadManager.progress)
                        
                        Text("\(Int(downloadManager.progress * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    
                    Text(downloadManager.progress > 0 ? "正在下载 3D 模型..." : "正在准备...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let error = error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        self.error = nil
                        self.isLoading = true
                        // Force delete cache and retry
                        let fileManager = FileManager.default
                        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let cachedURL = documentsDir.appendingPathComponent("Models").appendingPathComponent(url.lastPathComponent)
                        try? fileManager.removeItem(at: cachedURL)
                        loadModel()
                    }) {
                        Text("重试下载")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            loadModel()
        }
    }

    private func loadModel() {
        if url.isFileURL {
            loadFromLocalURL(url)
        } else {
            // Check cache first
            let fileManager = FileManager.default
            let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let modelsDir = documentsDir.appendingPathComponent("Models", isDirectory: true)
            
            if !fileManager.fileExists(atPath: modelsDir.path) {
                try? fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true)
            }
            
            let cachedURL = modelsDir.appendingPathComponent(url.lastPathComponent)
            
            if fileManager.fileExists(atPath: cachedURL.path) {
                // Verify cached file is not a Gitee error page (usually < 1KB)
                if let attrs = try? fileManager.attributesOfItem(atPath: cachedURL.path),
                   let size = attrs[.size] as? UInt64, size > 1024 {
                    print("📦 [Model3DView] Using cached model: \(cachedURL.lastPathComponent) (\(size) bytes)")
                    loadFromLocalURL(cachedURL)
                } else {
                    print("⚠️ [Model3DView] Cached file is invalid or too small, re-downloading...")
                    try? fileManager.removeItem(at: cachedURL)
                    downloadAndLoad(url, to: cachedURL)
                }
            } else {
                downloadAndLoad(url, to: cachedURL)
            }
        }
    }

    private func downloadAndLoad(_ remoteURL: URL, to destinationURL: URL) {
        Task {
            do {
                let localURL = try await downloadManager.download(url: remoteURL, to: destinationURL)
                
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: localURL, to: destinationURL)
                print("✅ [Model3DView] Saved to: \(destinationURL.lastPathComponent)")
                loadFromLocalURL(destinationURL)
            } catch {
                print("❌ [Model3DView] Download/Save error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.error = "下载失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func loadFromLocalURL(_ localURL: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // SCNScene natively supports .usdz
                let scnScene = try SCNScene(url: localURL, options: nil)
                
                // Ensure there's a camera and lighting
                setupScene(for: scnScene)
                
                DispatchQueue.main.async {
                    self.scene = scnScene
                    self.isLoading = false
                }
            } catch {
                print("❌ [Model3DView] Load error: \(error.localizedDescription)")
                
                // Fallback to ModelIO for more robust parsing
                let asset = MDLAsset(url: localURL)
                if asset.count > 0 {
                    let scnScene = SCNScene(mdlAsset: asset)
                    setupScene(for: scnScene)
                    DispatchQueue.main.async {
                        self.scene = scnScene
                        self.isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.error = "模型加载失败"
                        self.isLoading = false
                    }
                }
            }
        }
    }

    private func setupScene(for scnScene: SCNScene) {
        // Set background to clear for transparency
        scnScene.background.contents = UIColor.clear
        
        // Reset root node rotation to ensure frontal view
        // Rotate 90 degrees on X axis as requested to face the view
        scnScene.rootNode.rotation = SCNVector4(0, 0, 0, 0)
        scnScene.rootNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        
        let (boxMin, boxMax) = scnScene.rootNode.boundingBox
        let midX = (boxMax.x + boxMin.x) / 2
        let midY = (boxMax.y + boxMin.y) / 2
        let midZ = (boxMax.z + boxMin.z) / 2
        let radius = max(max(boxMax.x - boxMin.x, boxMax.y - boxMin.y), boxMax.z - boxMin.z)

        // 1. Ensure there's a camera
        let hasCamera = scnScene.rootNode.childNodes.contains { $0.camera != nil }
        if !hasCamera {
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.position = SCNVector3(x: midX, y: midY, z: midZ + radius * 2.5)
            scnScene.rootNode.addChildNode(cameraNode)
        }
        
        // 2. Add basic lighting if the scene is too dark
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor(white: 0.5, alpha: 1.0)
        scnScene.rootNode.addChildNode(ambientLightNode)
        
        let directionalLightNode = SCNNode()
        directionalLightNode.light = SCNLight()
        directionalLightNode.light?.type = .directional
        directionalLightNode.position = SCNVector3(x: midX + radius, y: midY + radius, z: midZ + radius)
        directionalLightNode.look(at: SCNVector3(midX, midY, midZ))
        scnScene.rootNode.addChildNode(directionalLightNode)
    }
}
