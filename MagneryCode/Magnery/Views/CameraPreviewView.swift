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
    var onTap: (CGPoint) -> Void = { _ in }
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.connection?.videoOrientation = .portrait
        
        // Add tap gesture for focus
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: CameraPreviewView
        
        init(_ parent: CameraPreviewView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ getter: UITapGestureRecognizer) {
            let location = getter.location(in: getter.view)
            guard let previewLayer = getter.view?.layer as? AVCaptureVideoPreviewLayer else { return }
            
            let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: location)
            parent.onTap(devicePoint)
            
            // Visual feedback
            showFocusIndicator(at: location, in: getter.view)
        }
        
        private func showFocusIndicator(at point: CGPoint, in view: UIView?) {
            guard let view = view else { return }
            
            let focusView = UIView(frame: CGRect(x: 0, y: 0, width: 70, height: 70))
            focusView.center = point
            focusView.backgroundColor = .clear
            focusView.layer.borderColor = UIColor.yellow.cgColor
            focusView.layer.borderWidth = 1.0
            focusView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            view.addSubview(focusView)
            
            UIView.animate(withDuration: 0.3, animations: {
                focusView.transform = .identity
            }) { _ in
                UIView.animate(withDuration: 0.3, delay: 0.5, options: .curveEaseOut, animations: {
                    focusView.alpha = 0
                }) { _ in
                    focusView.removeFromSuperview()
                }
            }
        }
    }
}

