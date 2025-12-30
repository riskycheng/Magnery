import Foundation
import Combine

class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var progress: Double = 0
    @Published var isDownloading = false
    @Published var error: Error?
    @Published var downloadedURL: URL?
    
    private var continuation: CheckedContinuation<URL, Error>?
    
    func download(url: URL, to destinationURL: URL) async throws -> URL {
        await MainActor.run {
            isDownloading = true
            progress = 0
            error = nil
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            let config = URLSessionConfiguration.ephemeral
            config.waitsForConnectivity = true
            config.timeoutIntervalForRequest = 20
            config.timeoutIntervalForResource = 60 // Max 1 minute for a single file
            
            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            let task = session.downloadTask(with: url)
            task.resume()
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let newProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            DispatchQueue.main.async {
                self.progress = newProgress
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let response = downloadTask.response as? HTTPURLResponse
        let statusCode = response?.statusCode ?? 0
        
        // Copy the file immediately on the background thread because 'location' is temporary
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.moveItem(at: location, to: tempURL)
        } catch {
            print("❌ [DownloadManager] Failed to move temp file: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isDownloading = false
                self.continuation?.resume(throwing: error)
                self.continuation = nil
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isDownloading = false
            self.progress = 1.0
            
            if statusCode != 200 {
                print("❌ [DownloadManager] HTTP Error: \(statusCode) for \(downloadTask.originalRequest?.url?.lastPathComponent ?? "unknown")")
                self.continuation?.resume(throwing: NSError(domain: "DownloadError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(statusCode)"]))
            } else {
                self.continuation?.resume(returning: tempURL)
            }
            self.continuation = nil
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            self.isDownloading = false
            if let error = error {
                print("❌ [DownloadManager] Task completed with error: \(error.localizedDescription)")
                self.continuation?.resume(throwing: error)
                self.continuation = nil
            } else if self.continuation != nil {
                // If didFinishDownloadingTo was never called but task finished without error
                print("❌ [DownloadManager] Task completed unexpectedly without error or file")
                self.continuation?.resume(throwing: NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Download failed unexpectedly"]))
                self.continuation = nil
            }
        }
    }
}
