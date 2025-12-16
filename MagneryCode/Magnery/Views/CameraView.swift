import SwiftUI
import UIKit

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
    
    var body: some View {
        ZStack {
            if cameraManager.isAuthorized {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
                
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
                        
                        Text("请将物体置于框内")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding(.bottom, 80)
                    
                    HStack(spacing: 60) {
                        Button(action: {
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
                        
                        Button(action: {
                            cameraManager.capturePhoto()
                        }) {
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
                                
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                            }
                        }
                        
                        Button(action: {
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
            ImagePicker(image: $cameraManager.capturedImage, sourceType: .photoLibrary)
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
        .fullScreenCover(isPresented: $showingSegmentation) {
            if let image = cameraManager.capturedImage {
                SegmentationView(originalImage: image)
            }
        }
        .onAppear {
            cameraManager.capturedImage = nil
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
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
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    CameraView()
}
