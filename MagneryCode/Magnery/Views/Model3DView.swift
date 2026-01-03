import SwiftUI
import SceneKit
import ModelIO
import SceneKit.ModelIO

struct Model3DView: View {
    let url: URL
    @State private var scene: SCNScene?
    @State private var cameraNode: SCNNode?
    @State private var isLoading = true
    @State private var error: String?
    @StateObject private var downloadManager = DownloadManager()

    var body: some View {
        ZStack {
            if let scene = scene {
                ZStack(alignment: .bottomLeading) {
                    TransparentSceneView(scene: scene, cameraNode: cameraNode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 3D Interaction Indicator
                    HStack(spacing: 6) {
                        Image(systemName: "move.3d")
                        Text("3D 可旋转")
                    }
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.2))
                            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                    )
                    .padding(20)
                }
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
                // Verify cached file is not an error page (usually < 1KB)
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
        
        // 1. Create a container node
        let modelContainer = SCNNode()
        for node in scnScene.rootNode.childNodes {
            modelContainer.addChildNode(node)
        }
        scnScene.rootNode.addChildNode(modelContainer)
        
        // 2. Calculate bounding box and center
        let (boxMin, boxMax) = modelContainer.boundingBox
        let midX = (boxMax.x + boxMin.x) / 2
        let midY = (boxMax.y + boxMin.y) / 2
        let midZ = (boxMax.z + boxMin.z) / 2
        let sizeX = boxMax.x - boxMin.x
        let sizeY = boxMax.y - boxMin.y
        let sizeZ = boxMax.z - boxMin.z
        let radius = max(max(sizeX, sizeY), sizeZ)
        
        // 3. Center the model's geometry within the container
        // This makes rotation happen around the model's actual center
        for node in modelContainer.childNodes {
            node.position = SCNVector3(
                node.position.x - midX,
                node.position.y - midY,
                node.position.z - midZ
            )
        }
        
        // 4. Apply orientation adjustment
        // Based on logs: X=1.15, Y=0.21, Z=1.15. Model is lying flat on XZ plane.
        // We rotate it 90 degrees on X to stand it up.
        modelContainer.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        
        // 5. Initial "Look Around" Animation
        // Rotate left and right (Yaw) to show it's 3D
        let rotateLeft = SCNAction.rotateBy(x: 0, y: -0.4, z: 0, duration: 0.8)
        rotateLeft.timingMode = .easeInEaseOut
        let rotateRight = SCNAction.rotateBy(x: 0, y: 0.8, z: 0, duration: 1.6)
        rotateRight.timingMode = .easeInEaseOut
        let rotateBack = SCNAction.rotateBy(x: 0, y: -0.4, z: 0, duration: 0.8)
        rotateBack.timingMode = .easeInEaseOut
        
        let sequence = SCNAction.sequence([
            SCNAction.wait(duration: 0.5),
            rotateLeft,
            rotateRight,
            rotateBack
        ])
        modelContainer.runAction(sequence)
        
        // 6. Create and position the camera
        let camera = SCNCamera()
        camera.zNear = 0.01
        camera.zFar = Double(radius) * 100.0
        
        let newCameraNode = SCNNode()
        newCameraNode.camera = camera
        
        // Since we centered the model at (0,0,0), the camera just needs to look at the origin
        newCameraNode.position = SCNVector3(x: 0, y: 0, z: radius * 1.3)
        scnScene.rootNode.addChildNode(newCameraNode)
        
        // 7. Add basic lighting
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor(white: 0.6, alpha: 1.0)
        scnScene.rootNode.addChildNode(ambientLightNode)
        
        // Main directional light (Sun-like)
        let directionalLightNode = SCNNode()
        directionalLightNode.light = SCNLight()
        directionalLightNode.light?.type = .directional
        directionalLightNode.light?.intensity = 1000
        directionalLightNode.light?.castsShadow = true
        directionalLightNode.position = SCNVector3(x: radius * 2, y: radius * 2, z: radius * 2)
        directionalLightNode.look(at: SCNVector3(0, 0, 0))
        scnScene.rootNode.addChildNode(directionalLightNode)
        
        // Fill light (Opposite side)
        let fillLightNode = SCNNode()
        fillLightNode.light = SCNLight()
        fillLightNode.light?.type = .directional
        fillLightNode.light?.intensity = 400
        fillLightNode.position = SCNVector3(x: -radius, y: radius, z: -radius)
        fillLightNode.look(at: SCNVector3(0, 0, 0))
        scnScene.rootNode.addChildNode(fillLightNode)
        
        // Top light
        let topLightNode = SCNNode()
        topLightNode.light = SCNLight()
        topLightNode.light?.type = .directional
        topLightNode.light?.intensity = 300
        topLightNode.position = SCNVector3(x: 0, y: radius * 2, z: 0)
        topLightNode.look(at: SCNVector3(0, 0, 0))
        scnScene.rootNode.addChildNode(topLightNode)
        
        DispatchQueue.main.async {
            self.cameraNode = newCameraNode
        }
    }
}

struct TransparentSceneView: UIViewRepresentable {
    let scene: SCNScene
    let cameraNode: SCNNode?
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.pointOfView = cameraNode
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor = .clear
        scnView.isOpaque = false
        scnView.antialiasingMode = .multisampling4X
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene = scene
        uiView.pointOfView = cameraNode
    }
}
