import SwiftUI
import Photos

struct SharePreviewView: View {
    @Environment(\.dismiss) var dismiss
    let item: MagnetItem
    @State private var selectedTemplate: ShareTemplate = .pure
    @State private var processedImages: [ShareTemplate: UIImage] = [:]
    @State private var isSaving = false
    @State private var showSuccessAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Paging Preview
                TabView(selection: $selectedTemplate) {
                    ForEach(ShareTemplate.allCases, id: \.self) { template in
                        VStack {
                            if let image = processedImages[template] {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(20)
                                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                                    .padding(30)
                            } else {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .tag(template)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)
                
                // Custom Page Indicator
                HStack(spacing: 12) {
                    ForEach(ShareTemplate.allCases, id: \.self) { template in
                        Circle()
                            .fill(selectedTemplate == template ? Color.primary : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(selectedTemplate == template ? 1.2 : 1.0)
                            .animation(.spring(), value: selectedTemplate)
                    }
                }
                .padding(.vertical, 20)
                
                // Template Name
                Text(selectedTemplate.rawValue)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 30)
                
                // Action Buttons
                HStack(spacing: 20) {
                    Button(action: saveToPhotos) {
                        VStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 24))
                            Text("保存相册")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(20)
                    }
                    .disabled(isSaving || processedImages[selectedTemplate] == nil)
                    
                    if let image = processedImages[selectedTemplate] {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview(item.name, image: Image(uiImage: image))) {
                            VStack(spacing: 8) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 24))
                                Text("分享好友")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
            .background(Color(red: 0.98, green: 0.98, blue: 1.0))
            .navigationTitle("分享灵感")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                generateAllImages()
            }
            .alert("保存成功", isPresented: $showSuccessAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("已为您保存至系统相册")
            }
        }
    }
    
    private func generateAllImages() {
        // Handle both local and remote images
        if item.imagePath.hasPrefix("http") {
            // Remote image
            guard let url = URL(string: item.imagePath) else {
                handleFailure()
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, _, error in
                if let data = data, let image = UIImage(data: data) {
                    processImage(image)
                } else {
                    print("Error downloading image: \(error?.localizedDescription ?? "Unknown error")")
                    handleFailure()
                }
            }.resume()
        } else if let localImage = ImageManager.shared.loadImage(filename: item.imagePath) {
            // Local image
            processImage(localImage)
        } else {
            handleFailure()
        }
    }
    
    private func handleFailure() {
        DispatchQueue.main.async {
            // If we can't load the image, we should at least stop the loading state
            // Maybe show an error or just dismiss
            dismiss()
        }
    }
    
    private func processImage(_ originalImage: UIImage) {
        // Pre-downscale once to save time and memory
        let maxDimension: CGFloat = 1200
        let scale = min(maxDimension / originalImage.size.width, maxDimension / originalImage.size.height, 1.0)
        let targetSize = CGSize(width: originalImage.size.width * scale, height: originalImage.size.height * scale)
        
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let downscaledImage = renderer.image { _ in
            originalImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        // Use a serial queue to process images one by one to prevent memory spikes
        let processingQueue = DispatchQueue(label: "com.magnery.share.processing", qos: .userInitiated)
        
        for template in ShareTemplate.allCases {
            processingQueue.async {
                let generated = ShareImageHelper.generateShareImage(for: downscaledImage, item: item, template: template)
                DispatchQueue.main.async {
                    self.processedImages[template] = generated
                }
            }
        }
    }
    
    private func saveToPhotos() {
        guard let image = processedImages[selectedTemplate] else { return }
        isSaving = true
        
        if selectedTemplate == .pure {
            // For pure template, save as PNG to preserve transparency
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                if let data = image.pngData() {
                    request.addResource(with: .photo, data: data, options: nil)
                }
            }) { success, error in
                DispatchQueue.main.async {
                    isSaving = false
                    if success {
                        showSuccessAlert = true
                    }
                }
            }
        } else {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSaving = false
                showSuccessAlert = true
            }
        }
    }
}
