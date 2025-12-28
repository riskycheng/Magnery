import SwiftUI
import AVFoundation
import Combine
import CoreLocation

class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isAuthorized = false
    @Published var capturedImage: UIImage?
    @Published var capturedFrames: [UIImage] = []
    @Published var segmentedFrames: [UIImage] = []
    @Published var isRecording = false
    @Published var isProcessingFrames = false
    @Published var processingProgress: Double = 0
    
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var photoDelegate: PhotoCaptureDelegate?
    private let sessionQueue = DispatchQueue(label: "com.magnery.camera.sessionQueue")
    private let videoQueue = DispatchQueue(label: "com.magnery.camera.videoQueue")
    private let processingQueue = DispatchQueue(label: "com.magnery.camera.processingQueue", qos: .userInitiated)
    private var isConfigured = false
    
    private var frameCounter = 0
    private let maxFrames = 600 // 60 seconds at 10fps
    private var processedResults: [Int: UIImage] = [:]
    private var totalCapturedCount = 0
    
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
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
                self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
                // Set video orientation
                if let connection = self.videoOutput.connection(with: .video) {
                    connection.videoOrientation = .portrait
                }
            }
            
            self.session.commitConfiguration()
            self.isConfigured = true
            print("✅ [CameraManager] Camera setup complete")
        }
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        
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
    
    func startRecording() {
        DispatchQueue.main.async {
            self.capturedFrames = []
            self.segmentedFrames = []
            self.processedResults = [:]
            self.totalCapturedCount = 0
            self.isRecording = true
            self.isProcessingFrames = true // Start showing processing state immediately
            self.processingProgress = 0
            self.frameCounter = 0
            print("⏺️ [CameraManager] Started recording frames")
        }
    }
    
    func stopRecording() {
        DispatchQueue.main.async {
            self.isRecording = false
            print("⏹️ [CameraManager] Stopped recording frames, captured \(self.totalCapturedCount) frames")
            self.checkProcessingCompletion()
        }
    }
    
    private func checkProcessingCompletion() {
        if !isRecording && processedResults.count == totalCapturedCount && totalCapturedCount > 0 {
            // All frames processed
            let sortedFrames = processedResults.keys.sorted().compactMap { processedResults[$0] }
            self.segmentedFrames = sortedFrames
            self.isProcessingFrames = false
            print("✅ [CameraManager] Finished processing all \(sortedFrames.count) frames")
        }
    }
    
    private func processFrameInBackground(image: UIImage, index: Int) {
        processingQueue.async {
            VisionService.shared.segmentAndNormalize(image: image) { segmentedImage in
                DispatchQueue.main.async {
                    if let segmented = segmentedImage {
                        self.processedResults[index] = segmented
                    }
                    
                    if self.totalCapturedCount > 0 {
                        self.processingProgress = Double(self.processedResults.count) / Double(self.totalCapturedCount)
                    }
                    
                    self.checkProcessingCompletion()
                }
            }
        }
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

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording else { return }
        
        // Capture every 3rd frame to avoid too many frames
        frameCounter += 1
        if frameCounter % 3 != 0 { return }
        
        if totalCapturedCount >= maxFrames {
            stopRecording()
            return
        }
        
        guard let image = imageFromSampleBuffer(sampleBuffer) else { return }
        
        let currentIndex = totalCapturedCount
        totalCapturedCount += 1
        
        DispatchQueue.main.async {
            self.capturedFrames.append(image)
            self.processFrameInBackground(image: image, index: currentIndex)
        }
    }
    
    private func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        // Since videoOrientation is set to .portrait, the buffer is already portrait.
        // Use .up to avoid double rotation.
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
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
