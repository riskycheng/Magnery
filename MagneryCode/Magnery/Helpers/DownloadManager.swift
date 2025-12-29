import Foundation
import Combine

class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var progress: Double = 0
    @Published var isDownloading = false
    @Published var error: Error?
    @Published var downloadedURL: URL?
    
    private var continuation: CheckedContinuation<URL, Error>?
    
    func download(url: URL, to destinationURL: URL) async throws -> URL {
        isDownloading = true
        progress = 0
        error = nil
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let task = session.downloadTask(with: url)
            task.resume()
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            DispatchQueue.main.async {
                self.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        isDownloading = false
        DispatchQueue.main.async {
            self.progress = 1.0
        }
        continuation?.resume(returning: location)
        continuation = nil
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        isDownloading = false
        if let error = error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
