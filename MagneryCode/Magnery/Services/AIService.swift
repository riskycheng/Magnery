import Foundation
import Network
import SwiftUI
import Combine

enum AIModelType: String, CaseIterable {
    case easy = "基础版 (VL-32B)"
    case medium = "专业版 (VL-30B-Thinking)"
    case powerful = "旗舰版 (VL-32B-Instruct)"
    
    var modelName: String {
        switch self {
        case .easy:
            return "Qwen/Qwen2.5-VL-32B-Instruct"
        case .medium:
            return "Qwen/Qwen3-VL-30B-A3B-Thinking"
        case .powerful:
            return "Qwen/Qwen3-VL-32B-Instruct"
        }
    }
    
    var description: String {
        switch self {
        case .easy:
            return "快速视觉识别，生成简洁描述"
        case .medium:
            return "深度思考模式，挖掘物品背后的细节"
        case .powerful:
            return "最强视觉理解，生成极具质感的描述"
        }
    }
}

class AIService: ObservableObject {
    static let shared = AIService()
    
    private let apiKey = "sk-ezwzqwedwhtnbyitbnyohvzanpitqqlnpjucejddpozmpjxj" // SiliconFlow API Key
    private let baseURL = "https://api.siliconflow.cn/v1/chat/completions"
    
    private init() {}
    
    enum AIServiceError: Error {
        case invalidResponse
        case requestFailed(String)
        case parseError
        
        var localizedDescription: String {
            switch self {
            case .invalidResponse: return "服务器响应无效"
            case .requestFailed(let msg): return "请求失败: \(msg)"
            case .parseError: return "解析响应失败"
            }
        }
    }
    
    // Multi-modal message structures
    struct Message: Codable {
        let role: String
        let content: MessageContent
    }
    
    enum MessageContent: Codable {
        case text(String)
        case parts([ContentPart])
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let s): try container.encode(s)
            case .parts(let p): try container.encode(p)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let s = try? container.decode(String.self) {
                self = .text(s)
            } else {
                let p = try container.decode([ContentPart].self)
                self = .parts(p)
            }
        }
    }
    
    struct ContentPart: Codable {
        let type: String
        var text: String? = nil
        var image_url: ImageURL? = nil
        
        struct ImageURL: Codable {
            let url: String
        }
    }
    
    struct ChatRequest: Codable {
        let model: String
        let messages: [Message]
        let stream: Bool = false
        let max_tokens: Int = 512
        let temperature: Double = 0.7
    }
    
    struct ChatResponse: Codable {
        struct Choice: Codable {
            struct ResponseMessage: Codable {
                let role: String
                let content: String
            }
            let message: ResponseMessage
        }
        let choices: [Choice]
    }
    
    func generateCaption(itemName: String, location: String, date: Date, image: UIImage?, modelType: AIModelType) async throws -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        let dateString = dateFormatter.string(from: date)
        
        let systemPrompt = """
        你是一个专业的冰箱贴收藏助手。请根据用户提供的冰箱贴名称、位置、采集时间以及图片，生成一段简短的描述。
        
        约束条件：
        1. 字数严格控制在30字以内。
        2. 不要包含任何特殊符号、表情符号（Emoji）。
        3. 重点描述物体的外观特征、工艺质感或其展现的艺术价值。
        4. 描述要自然、有质感，不要在输出中包含时间、地点等客观背景信息。
        5. 直接返回描述文本，不要包含任何其他解释。
        """
        
        var userContentParts: [ContentPart] = [
            .init(type: "text", text: "冰箱贴名称：\(itemName)\n采集位置：\(location)\n采集时间：\(dateString)")
        ]
        
        if let image = image, let imageData = image.jpegData(compressionQuality: 0.7) {
            let base64Image = imageData.base64EncodedString()
            userContentParts.append(.init(type: "image_url", image_url: .init(url: "data:image/jpeg;base64,\(base64Image)")))
        }
        
        let messages = [
            Message(role: "system", content: .text(systemPrompt)),
            Message(role: "user", content: .parts(userContentParts))
        ]
        
        let requestBody = ChatRequest(model: modelType.modelName, messages: messages)
        
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.requestFailed("无效的 URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "未知错误"
            throw AIServiceError.requestFailed(errorMsg)
        }
        
        let apiResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        
        guard let content = apiResponse.choices.first?.message.content else {
            throw AIServiceError.invalidResponse
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
