import SwiftUI

struct SharePreviewView: View {
    @Environment(\.dismiss) var dismiss
    let item: MagnetItem
    @State private var selectedTemplate: ShareTemplate = .classic
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
        guard let originalImage = ImageManager.shared.loadImage(filename: item.imagePath) else { return }
        
        for template in ShareTemplate.allCases {
            DispatchQueue.global(qos: .userInitiated).async {
                let generated = ShareImageHelper.generateShareImage(for: originalImage, item: item, template: template)
                DispatchQueue.main.async {
                    self.processedImages[template] = generated
                }
            }
        }
    }
    
    private func saveToPhotos() {
        guard let image = processedImages[selectedTemplate] else { return }
        isSaving = true
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            showSuccessAlert = true
        }
    }
}
