import SwiftUI
import AVFoundation
import Combine

struct CameraPreviewView: UIViewRepresentable {
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.connection?.videoOrientation = .portrait
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {}
}

class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isAuthorized = false
    @Published var capturedImage: UIImage?
    
    private let photoOutput = AVCapturePhotoOutput()
    private var photoDelegate: PhotoCaptureDelegate?
    private let sessionQueue = DispatchQueue(label: "com.magnery.camera.sessionQueue")
    private var isConfigured = false
    
    override init() {
        super.init()
        checkAuthorization()
    }
    
    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    if granted {
                        self.setupCamera()
                        self.startSession()
                    }
                }
            }
        default:
            isAuthorized = false
        }
    }
    
    func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isConfigured { return }
            
            self.session.beginConfiguration()
            
            // Clean up existing inputs/outputs
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                self.session.commitConfiguration()
                return
            }
            
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.maxPhotoQualityPrioritization = .quality
            }
            
            self.session.commitConfiguration()
            self.isConfigured = true
            print("✅ [CameraManager] Camera setup complete")
        }
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        
        // Enable high quality and metadata
        if #available(iOS 13.0, *) {
            settings.photoQualityPrioritization = .quality
        }
        
        photoDelegate = PhotoCaptureDelegate { image in
            DispatchQueue.main.async {
                self.capturedImage = image
            }
        }
        photoOutput.capturePhoto(with: settings, delegate: photoDelegate!)
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                print("⏹️ [CameraManager] Session stopped")
            }
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.isAuthorized else { 
                print("⚠️ [CameraManager] Cannot start session: Not authorized")
                return 
            }
            
            if !self.isConfigured {
                print("⚠️ [CameraManager] Session not configured yet, skipping start")
                return
            }
            
            if !self.session.isRunning {
                self.session.startRunning()
                print("▶️ [CameraManager] Session started")
            }
        }
    }
}

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void
    
    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation() else {
            print("❌ [PhotoCaptureDelegate] Error capturing photo: \(error?.localizedDescription ?? "Unknown error")")
            completion(nil)
            return
        }
        
        // Save to temporary file to preserve EXIF metadata
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        do {
            try imageData.write(to: tempURL)
            ImageMetadataCache.shared.storeFileURL(tempURL)
            print("✅ [PhotoCaptureDelegate] Saved photo with metadata to: \(tempURL.lastPathComponent)")
        } catch {
            print("❌ [PhotoCaptureDelegate] Failed to save temp file: \(error.localizedDescription)")
        }
        
        if let image = UIImage(data: imageData) {
            completion(image)
        } else {
            completion(nil)
        }
    }
}
