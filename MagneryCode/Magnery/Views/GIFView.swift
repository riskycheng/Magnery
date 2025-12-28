import SwiftUI
import WebKit

struct GIFView: View {
    let url: URL
    
    var body: some View {
        ZStack {
            GIFWebView(url: url)
            
            // Transparent overlay to ensure touches are captured by SwiftUI gestures/links
            // and not swallowed by the underlying WKWebView
            Color.black.opacity(0.001)
        }
        .contentShape(Rectangle())
    }
}

struct GIFWebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        webView.backgroundColor = .clear
        webView.isOpaque = false
        
        if url.isFileURL {
            if let data = try? Data(contentsOf: url) {
                webView.load(data, mimeType: "image/gif", characterEncodingName: "UTF-8", baseURL: url.deletingLastPathComponent())
            }
        } else {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            webView.load(request)
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No-op to prevent unnecessary reloads
    }
}
