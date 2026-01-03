import Foundation
import CryptoKit

class Tencent3DService {
    static let shared = Tencent3DService()
    
    private let secretId = "AKIDFuUtVvHRN90kKlJj4Wv9B2iDZkmg9Qcc"
    private let secretKey = "rX6SeeSZZRAnMNCFCyiWBdswoU0MVSEm"
    private let service = "ai3d"
    private let host = "ai3d.tencentcloudapi.com"
    private let version = "2025-05-13"
    private let region = "ap-guangzhou" // Default region
    
    private init() {}
    
    /// Submits a job to generate a 3D model from an image
    func submitJob(imageBase64: String) async throws -> String {
        let action = "SubmitHunyuanTo3DRapidJob"
        let payload: [String: Any] = [
            "ImageBase64": imageBase64,
            "ResultFormat": "USDZ",
            "EnablePBR": true
        ]
        
        let response = try await sendRequest(action: action, payload: payload)
        guard let data = response["Response"] as? [String: Any],
              let jobId = data["JobId"] as? String else {
            throw NSError(domain: "Tencent3DService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get JobId from response: \(response)"])
        }
        
        return jobId
    }
    
    /// Polls the job status until it's finished or failed
    func pollJobStatus(jobId: String) async throws -> String {
        let action = "QueryHunyuanTo3DRapidJob"
        let payload: [String: Any] = [
            "JobId": jobId
        ]
        
        while true {
            let response = try await sendRequest(action: action, payload: payload)
            guard let data = response["Response"] as? [String: Any],
                  let status = data["Status"] as? String else {
                throw NSError(domain: "Tencent3DService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get status from response"])
            }
            
            if status == "DONE" {
                guard let file3Ds = data["ResultFile3Ds"] as? [[String: Any]],
                      let firstFile = file3Ds.first,
                      let usdzUrl = firstFile["Url"] as? String else {
                    throw NSError(domain: "Tencent3DService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Job succeeded but UsdzUrl is missing"])
                }
                return usdzUrl
            } else if status == "FAIL" {
                let errorMsg = (data["ErrorMsg"] as? String) ?? "Unknown error"
                throw NSError(domain: "Tencent3DService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Job failed: \(errorMsg)"])
            }
            
            // Wait for 5 seconds before polling again
            try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
        }
    }
    
    private func sendRequest(action: String, payload: [String: Any]) async throws -> [String: Any] {
        let endpoint = "https://\(host)"
        let algorithm = "TC3-HMAC-SHA256"
        let timestamp = Int(Date().timeIntervalSince1970)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let date = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
        
        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [])
        let payloadString = String(data: payloadData, encoding: .utf8) ?? "{}"
        
        // 1. Canonical Request
        let httpRequestMethod = "POST"
        let canonicalUri = "/"
        let canonicalQuerystring = ""
        let ct = "application/json; charset=utf-8"
        let canonicalHeaders = "content-type:\(ct)\nhost:\(host)\nx-tc-action:\(action.lowercased())\n"
        let signedHeaders = "content-type;host;x-tc-action"
        let hashedRequestPayload = sha256(payloadString)
        
        let canonicalRequest = "\(httpRequestMethod)\n\(canonicalUri)\n\(canonicalQuerystring)\n\(canonicalHeaders)\n\(signedHeaders)\n\(hashedRequestPayload)"
        
        // 2. String to Sign
        let credentialScope = "\(date)/\(service)/tc3_request"
        let hashedCanonicalRequest = sha256(canonicalRequest)
        let stringToSign = "\(algorithm)\n\(timestamp)\n\(credentialScope)\n\(hashedCanonicalRequest)"
        
        // 3. Calculate Signature
        let secretDate = hmac(key: "TC3\(secretKey)".data(using: .utf8)!, data: date.data(using: .utf8)!)
        let secretService = hmac(key: secretDate, data: service.data(using: .utf8)!)
        let secretSigning = hmac(key: secretService, data: "tc3_request".data(using: .utf8)!)
        let signature = hmac(key: secretSigning, data: stringToSign.data(using: .utf8)!).map { String(format: "%02hhx", $0) }.joined()
        
        // 4. Authorization Header
        let authorization = "\(algorithm) Credential=\(secretId)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        
        // 5. Perform Request
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.httpBody = payloadData
        request.setValue(ct, forHTTPHeaderField: "Content-Type")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue(action, forHTTPHeaderField: "X-TC-Action")
        request.setValue(version, forHTTPHeaderField: "X-TC-Version")
        request.setValue(region, forHTTPHeaderField: "X-TC-Region")
        request.setValue(String(timestamp), forHTTPHeaderField: "X-TC-Timestamp")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            throw NSError(domain: "Tencent3DService", code: -1, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(errorBody)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NSError(domain: "Tencent3DService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }
        
        return json
    }
    
    private func sha256(_ msg: String) -> String {
        let data = msg.data(using: .utf8)!
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func hmac(key: Data, data: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let authenticationCode = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(authenticationCode)
    }
}
