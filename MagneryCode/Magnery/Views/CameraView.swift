import SwiftUI
import UIKit
import Photos
import PhotosUI
import UniformTypeIdentifiers

// Temporary cache for storing original image file URLs with EXIF data
class ImageMetadataCache {
    static let shared = ImageMetadataCache()
    private var fileURL: URL?
    
    func storeFileURL(_ url: URL) {
        // Clean up old file if exists
        if let oldURL = fileURL {
            try? FileManager.default.removeItem(at: oldURL)
        }
        fileURL = url
        print("📦 [MetadataCache] Stored file URL: \(url.lastPathComponent)")
    }
    
    func getFileURL() -> URL? {
        print("📦 [MetadataCache] Retrieved file URL: \(fileURL?.lastPathComponent ?? "nil")")
        return fileURL
    }
    
    func clearFileURL() {
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
            print("📦 [MetadataCache] Cleaned up file: \(url.lastPathComponent)")
        }
        fileURL = nil
    }
}

enum BracketPosition {
    case topLeft, topRight, bottomLeft, bottomRight
}

struct CornerBracket: View {
    let position: BracketPosition
    let size: CGFloat = 40
    let thickness: CGFloat = 4
    let radius: CGFloat = 20
    
    var body: some View {
        Path { path in
            switch position {
            case .topLeft:
                path.move(to: CGPoint(x: 0, y: size))
                path.addLine(to: CGPoint(x: 0, y: radius))
                path.addArc(center: CGPoint(x: radius, y: radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
                path.addLine(to: CGPoint(x: size, y: 0))
            case .topRight:
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: size - radius, y: 0))
                path.addArc(center: CGPoint(x: size - radius, y: radius), radius: radius, startAngle: .degrees(270), endAngle: .degrees(360), clockwise: false)
                path.addLine(to: CGPoint(x: size, y: size))
            case .bottomLeft:
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: size - radius))
                path.addArc(center: CGPoint(x: radius, y: size - radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
                path.addLine(to: CGPoint(x: size, y: size))
            case .bottomRight:
                path.move(to: CGPoint(x: size, y: 0))
                path.addLine(to: CGPoint(x: size, y: size - radius))
                path.addArc(center: CGPoint(x: size - radius, y: size - radius), radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
                path.addLine(to: CGPoint(x: 0, y: size))
            }
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
        .frame(width: size, height: size)
    }
}

struct CameraView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var showingImagePicker = false
    @State private var showingSegmentation = false
    @State private var isProcessingGIF = false
    @State private var capturedGIFURL: URL?
    @State private var selectedVideoURL: URL?
    
    var body: some View {
        ZStack {
            if cameraManager.isAuthorized {
                CameraPreviewView(session: cameraManager.session) { point in
                    cameraManager.focus(at: point)
                }
                .ignoresSafeArea()
                
                if cameraManager.isRecording {
                    Color.red.opacity(0.1)
                        .ignoresSafeArea()
                        .overlay(
                            VStack {
                                Text("正在录制...")
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(10)
                                    .padding(.top, 100)
                                Spacer()
                            }
                        )
                }
                
                if cameraManager.isProcessingFrames && !cameraManager.isRecording {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                        .overlay(
                            VStack(spacing: 20) {
                                ProgressView(value: cameraManager.processingProgress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                                    .frame(width: 200)
                                Text("正在智能分割每一帧... \(Int(cameraManager.processingProgress * 100))%")
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                            }
                        )
                }
                
                VStack {
                    HStack {
                        Text(dateString)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                            .padding(.leading, 20)
                            .padding(.top, 20)
                        
                        Spacer()
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 30) {
                        ZStack {
                            VStack {
                                HStack {
                                    CornerBracket(position: .topLeft)
                                    Spacer()
                                    CornerBracket(position: .topRight)
                                }
                                Spacer()
                                HStack {
                                    CornerBracket(position: .bottomLeft)
                                    Spacer()
                                    CornerBracket(position: .bottomRight)
                                }
                            }
                            .padding(20)
                            .frame(width: UIScreen.main.bounds.width - 40, height: UIScreen.main.bounds.width - 40)
                        }
                        
                        Text(cameraManager.isRecording ? "松开结束录制" : "请将物体置于框内")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding(.bottom, 80)
                    
                    HStack(spacing: 60) {
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            cameraManager.stopSession()
                            dismiss()
                        }) {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                )
                        }
                        
                        // Capture Button with Long Press
                        ZStack {
                            Circle()
                                .stroke(
                                    AngularGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.95, blue: 0.6),
                                            Color(red: 0.4, green: 0.8, blue: 0.5),
                                            Color(red: 0.5, green: 0.6, blue: 1.0),
                                            Color(red: 1.0, green: 0.95, blue: 0.6)
                                        ],
                                        center: .center
                                    ),
                                    lineWidth: 4
                                )
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(cameraManager.isRecording ? 360 : 0))
                                .animation(cameraManager.isRecording ? .linear(duration: 2).repeatForever(autoreverses: false) : .default, value: cameraManager.isRecording)
                            
                            Circle()
                                .fill(cameraManager.isRecording ? Color.red : Color.white)
                                .frame(width: 70, height: 70)
                                .scaleEffect(cameraManager.isRecording ? 0.8 : 1.0)
                                .animation(.spring(), value: cameraManager.isRecording)
                        }
                        .onTapGesture {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            cameraManager.capturePhoto()
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    let impact = UIImpactFeedbackGenerator(style: .heavy)
                                    impact.impactOccurred()
                                    cameraManager.startRecording()
                                }
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { _ in
                                    if cameraManager.isRecording {
                                        cameraManager.stopRecording()
                                    }
                                }
                        )
                        
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            cameraManager.stopSession()
                            showingImagePicker = true
                        }) {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .padding(.bottom, 40)
                }
                
                if isProcessingGIF {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .overlay(
                            VStack(spacing: 20) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                Text("正在生成 GIF...")
                                    .foregroundColor(.white)
                                    .font(.headline)
                            }
                        )
                }
            } else {
                Color.black.ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    Text("需要相机权限")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $cameraManager.capturedImage, videoURL: $selectedVideoURL, sourceType: .photoLibrary)
        }
        .onChange(of: selectedVideoURL) { oldValue, newValue in
            if let url = newValue {
                cameraManager.stopSession()
                cameraManager.processVideo(at: url)
                selectedVideoURL = nil
            }
        }
        .onChange(of: cameraManager.capturedImage) { oldValue, newValue in
            if newValue != nil {
                cameraManager.stopSession()
                showingSegmentation = true
            }
        }
        .onChange(of: showingSegmentation) { oldValue, newValue in
            if !newValue {
                cameraManager.capturedImage = nil
                cameraManager.startSession()
            }
        }
        .onChange(of: cameraManager.isProcessingFrames) { oldValue, newValue in
            if oldValue == true && newValue == false && !cameraManager.segmentedFrames.isEmpty {
                processCapturedFrames()
            }
        }
        .fullScreenCover(isPresented: $showingSegmentation) {
            if let image = cameraManager.capturedImage {
                SegmentationView(originalImage: image, gifURL: capturedGIFURL)
            }
        }
        .onAppear {
            cameraManager.capturedImage = nil
            capturedGIFURL = nil
            cameraManager.startSession()
            LocationManager.shared.requestAuthorization()
            LocationManager.shared.startUpdatingLocation()
        }
        .onDisappear {
            cameraManager.stopSession()
            LocationManager.shared.stopUpdatingLocation()
        }
    }
    
    private func processCapturedFrames() {
        guard !cameraManager.segmentedFrames.isEmpty else { return }
        
        isProcessingGIF = true
        
        // Use the first frame as the main image (but we need a non-transparent one for the placeholder)
        // Actually, let's use the first original frame as the placeholder
        cameraManager.capturedImage = cameraManager.capturedFrames.first
        
        GIFService.shared.createGIF(from: cameraManager.segmentedFrames) { url in
            DispatchQueue.main.async {
                self.capturedGIFURL = url
                self.isProcessingGIF = false
                
                if url != nil {
                    print("✅ [CameraView] Segmented GIF generated successfully: \(url!)")
                    self.showingSegmentation = true
                } else {
                    print("❌ [CameraView] GIF generation failed")
                }
            }
        }
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月 d日"
        return formatter.string(from: Date())
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var videoURL: Binding<URL?>? = nil
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIViewController {
        // Use PHPickerViewController for photo library (modern API with better metadata support)
        if sourceType == .photoLibrary {
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = .any(of: [.images, .videos])
            configuration.selectionLimit = 1
            configuration.preferredAssetRepresentationMode = .current  // Get the current version with edits
            
            print("📋 [ImagePicker] Creating PHPickerViewController with configuration")
            
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = context.coordinator
            return picker
        } else {
            // Use UIImagePickerController for camera
            print("📋 [ImagePicker] Creating UIImagePickerController for camera")
            let picker = UIImagePickerController()
            picker.sourceType = sourceType
            picker.delegate = context.coordinator
            return picker
        }
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("🖼️ [ImagePicker] Image selected from library")
            print("🖼️ [ImagePicker] Available info keys: \(info.keys.map { $0.rawValue })")
            
            // Try to get PHAsset for full metadata access
            if let asset = info[.phAsset] as? PHAsset {
                print("✅ [ImagePicker] Got PHAsset directly")
                loadImageWithMetadata(from: asset)
            } else if let referenceURL = info[.referenceURL] as? URL {
                // Try to get PHAsset from reference URL
                print("✅ [ImagePicker] Got reference URL: \(referenceURL)")
                let fetchResult = PHAsset.fetchAssets(withALAssetURLs: [referenceURL], options: nil)
                if let asset = fetchResult.firstObject {
                    print("✅ [ImagePicker] Fetched PHAsset from reference URL")
                    loadImageWithMetadata(from: asset)
                } else {
                    print("⚠️ [ImagePicker] Could not fetch PHAsset from reference URL")
                    if let imageURL = info[.imageURL] as? URL {
                        loadImageFromURL(imageURL)
                    } else if let image = info[.originalImage] as? UIImage {
                        parent.image = image
                        parent.dismiss()
                    }
                }
            } else if let imageURL = info[.imageURL] as? URL {
                print("⚠️ [ImagePicker] Only got image URL (no PHAsset): \(imageURL)")
                loadImageFromURL(imageURL)
            } else if let image = info[.originalImage] as? UIImage {
                print("⚠️ [ImagePicker] Only got UIImage, EXIF may be missing")
                parent.image = image
                parent.dismiss()
            } else {
                print("❌ [ImagePicker] Failed to get image")
                parent.dismiss()
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("❌ [ImagePicker] User cancelled")
            parent.dismiss()
        }
        
        // PHPickerViewControllerDelegate
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            print("🖼️ [PHPicker] Picker finished with \(results.count) results")
            
            guard let result = results.first else {
                print("❌ [PHPicker] No results selected")
                parent.dismiss()
                return
            }
            
            print("✅ [PHPicker] Got result with identifier: \(result.assetIdentifier ?? "nil")")
            
            // Load file representation to preserve EXIF data
            print("📂 [PHPicker] Loading file representation to preserve EXIF...")
            
            let itemProvider = result.itemProvider
            
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                print("🎬 [PHPicker] Video selected")
                itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    if let error = error {
                        print("❌ [PHPicker] Error loading video: \(error.localizedDescription)")
                        return
                    }
                    
                    if let url = url {
                        // Copy to temp location because the original URL is temporary and will be deleted
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                        try? FileManager.default.copyItem(at: url, to: tempURL)
                        
                        DispatchQueue.main.async {
                            self.parent.videoURL?.wrappedValue = tempURL
                            self.parent.dismiss()
                        }
                    }
                }
                return
            }
            
            // Check if we can load as an image
            if itemProvider.canLoadObject(ofClass: UIImage.self) {
                // Load the file representation (this preserves EXIF data)
                itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ [PHPicker] Error loading file representation: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.parent.dismiss()
                        }
                        return
                    }
                    
                    guard let url = url else {
                        print("❌ [PHPicker] No URL returned from file representation")
                        DispatchQueue.main.async {
                            self.parent.dismiss()
                        }
                        return
                    }
                    
                    print("✅ [PHPicker] Got file URL: \(url)")
                    
                    // IMPORTANT: Extract EXIF from the URL BEFORE creating UIImage
                    // UIImage creation strips EXIF data!
                    print("🧪 [PHPicker] Extracting EXIF from file URL BEFORE creating UIImage...")
                    let metadataFromFile = EXIFHelper.extractBasicMetadata(from: url)
                    print("🧪 [PHPicker] File EXIF result - Date: \(metadataFromFile.date?.description ?? "nil"), Coords: \(metadataFromFile.coordinates != nil ? "YES" : "NO")")
                    
                    // Copy the file to a persistent location so we can extract EXIF later
                    let tempDirectory = FileManager.default.temporaryDirectory
                    let destinationURL = tempDirectory.appendingPathComponent("original_\(UUID().uuidString).\(url.pathExtension)")
                    
                    do {
                        // Copy the file
                        try FileManager.default.copyItem(at: url, to: destinationURL)
                        print("✅ [PHPicker] Copied file to: \(destinationURL)")
                        
                        // Store the URL for later EXIF extraction
                        ImageMetadataCache.shared.storeFileURL(destinationURL)
                        
                        // Load image data
                        let imageData = try Data(contentsOf: url)
                        print("✅ [PHPicker] Loaded image data: \(imageData.count) bytes")
                        
                        if let image = UIImage(data: imageData) {
                            print("✅ [PHPicker] Created UIImage, size: \(image.size)")
                            
                            DispatchQueue.main.async {
                                self.parent.image = image
                                self.parent.dismiss()
                            }
                        } else {
                            print("❌ [PHPicker] Failed to create UIImage from data")
                            DispatchQueue.main.async {
                                self.parent.dismiss()
                            }
                        }
                    } catch {
                        print("❌ [PHPicker] Error: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.parent.dismiss()
                        }
                    }
                }
            } else {
                print("❌ [PHPicker] Cannot load as image")
                parent.dismiss()
            }
        }
        
        private func loadImageWithMetadata(from asset: PHAsset) {
            let options = PHImageRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { [weak self] imageData, dataUTI, orientation, info in
                guard let self = self else { return }
                
                if let imageData = imageData {
                    print("✅ [ImagePicker] Got image data from PHAsset: \(imageData.count) bytes")
                    
                    // Save to temp file to preserve EXIF
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                    try? imageData.write(to: tempURL)
                    ImageMetadataCache.shared.storeFileURL(tempURL)
                    
                    if let image = UIImage(data: imageData) {
                        print("✅ [ImagePicker] Created UIImage from PHAsset data")
                        
                        DispatchQueue.main.async {
                            self.parent.image = image
                            self.parent.dismiss()
                        }
                    } else {
                        print("❌ [ImagePicker] Failed to create UIImage from data")
                        DispatchQueue.main.async {
                            self.parent.dismiss()
                        }
                    }
                } else {
                    print("❌ [ImagePicker] Failed to get image data from PHAsset")
                    DispatchQueue.main.async {
                        self.parent.dismiss()
                    }
                }
            }
        }
        
        private func loadImageFromURL(_ url: URL) {
            do {
                let imageData = try Data(contentsOf: url)
                print("✅ [ImagePicker] Loaded image data from URL: \(imageData.count) bytes")
                
                // Save to temp file to preserve EXIF
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                try? imageData.write(to: tempURL)
                ImageMetadataCache.shared.storeFileURL(tempURL)
                
                if let image = UIImage(data: imageData) {
                    print("✅ [ImagePicker] Created UIImage from URL data")
                    parent.image = image
                } else {
                    print("❌ [ImagePicker] Failed to create UIImage from URL data")
                }
            } catch {
                print("❌ [ImagePicker] Error loading from URL: \(error.localizedDescription)")
            }
            parent.dismiss()
        }
    }
}

#Preview {
    CameraView()
}
