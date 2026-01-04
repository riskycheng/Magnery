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
    
    let chatSystemPrompt = """
    你是一个博学多才、温文尔雅的文化遗产专家和资深导游。
    
    在与用户的对话中，请遵循以下原则：
    1. 回答应该尽可能的简洁，不要太过复杂和冗长。
    2. 紧扣用户的问题，特别介绍该物品的特点。
    3. 如果该物品有历史背景，请着重讲解历史信息。
    4. 回答控制在200字以内，可以更短，但绝对不要超出200字。
    5. 你的角色是一个知识渊博的，有深厚历史知识的导游或者学者。语气要亲切、专业且富有感染力。
    """
    
    private let apiKey = "sk-ezwzqwedwhtnbyitbnyohvzanpitqqlnpjucejddpozmpjxj" // SiliconFlow API Key
    private let baseURL = "https://api.siliconflow.cn/v1/chat/completions"
    private let ttsURL = "https://api.siliconflow.cn/v1/audio/speech"
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }()
    
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
    struct Message: Codable, Equatable {
        let role: String
        let content: MessageContent
    }
    
    enum MessageContent: Codable, Equatable {
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
    
    struct ContentPart: Codable, Equatable {
        let type: String
        var text: String? = nil
        var image_url: ImageURL? = nil
        
        struct ImageURL: Codable, Equatable {
            let url: String
        }
    }
    
    struct ChatRequest: Codable {
        let model: String
        let messages: [Message]
        var stream: Bool = false
        var max_tokens: Int = 512
        var temperature: Double = 0.7
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

    struct ChatStreamResponse: Codable {
        struct Choice: Codable {
            struct Delta: Codable {
                let content: String?
            }
            let delta: Delta
            let finish_reason: String?
        }
        let choices: [Choice]
    }
    
    private func performChatRequest(_ requestBody: ChatRequest) async throws -> String {
        print("🚀 [AIService] Starting non-stream request. Model: \(requestBody.model), Messages: \(requestBody.messages.count)")
        
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.requestFailed("无效的 URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "未知错误"
            print("❌ [AIService] Request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1). Error: \(errorMsg)")
            throw AIServiceError.requestFailed(errorMsg)
        }
        
        let apiResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        
        guard let content = apiResponse.choices.first?.message.content else {
            print("❌ [AIService] Invalid response format")
            throw AIServiceError.invalidResponse
        }
        
        print("✅ [AIService] Request completed. Response length: \(content.count)")
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
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
        
        if let image = image {
            let resizedImage = resizeImage(image, targetSize: CGSize(width: 1024, height: 1024))
            if let imageData = resizedImage.jpegData(compressionQuality: 0.6) {
                let base64Image = imageData.base64EncodedString()
                userContentParts.append(.init(type: "image_url", image_url: .init(url: "data:image/jpeg;base64,\(base64Image)")))
            }
        }
        
        let messages = [
            Message(role: "system", content: .text(systemPrompt)),
            Message(role: "user", content: .parts(userContentParts))
        ]
        
        let requestBody = ChatRequest(model: modelType.modelName, messages: messages)
        return try await performChatRequest(requestBody)
    }
    
    func generateIntroduction(itemName: String, location: String, date: Date, image: UIImage?, modelType: AIModelType) async throws -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年MM月dd日"
        let dateString = dateFormatter.string(from: date)
        
        let systemPrompt = """
        你是一个博学多才的文化遗产专家和科普作家。请根据用户提供的冰箱贴（通常是某个景点、文物或文化符号的缩影）信息，生成一段详细的科普介绍。
        
        要求：
        1. 字数在200字左右。
        2. 内容应涵盖该物体的历史背景、文化内涵、艺术特色或背后的有趣故事。
        3. 语言风格要生动有趣，既有学术的严谨性，又不失科普的趣味性。
        4. 重点介绍冰箱贴所代表的实体（如：灵隐寺、龙门石窟等），而不是冰箱贴本身。
        5. 直接返回科普内容，不要包含任何其他解释或前缀。
        """
        
        var userContentParts: [ContentPart] = [
            .init(type: "text", text: "名称：\(itemName)\n相关位置：\(location)\n采集日期：\(dateString)")
        ]
        
        if let image = image, let imageData = image.jpegData(compressionQuality: 0.7) {
            let base64Image = imageData.base64EncodedString()
            userContentParts.append(.init(type: "image_url", image_url: .init(url: "data:image/jpeg;base64,\(base64Image)")))
        }
        
        let messages = [
            Message(role: "system", content: .text(systemPrompt)),
            Message(role: "user", content: .parts(userContentParts))
        ]
        
        var requestBody = ChatRequest(model: modelType.modelName, messages: messages)
        requestBody.max_tokens = 1024
        return try await performChatRequest(requestBody)
    }
    
    func generateIntroductionStream(itemName: String, location: String, date: Date, image: UIImage?, modelType: AIModelType) -> AsyncThrowingStream<String, Error> {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年MM月dd日"
        let dateString = dateFormatter.string(from: date)
        
        let systemPrompt = """
        你是一个博学多才、温文尔雅的文化遗产专家和资深导游。请根据用户提供的冰箱贴（通常是某个景点、文物或文化符号的缩影）信息，生成一段极具质感的科普介绍。
        
        要求：
        1. 角色定位：你是一位有着深厚历史底蕴的学者，语气要亲切且专业。
        2. 内容重点：着重讲解该物体的历史背景、文化内涵、艺术特色。如果有相关的历史典故，请简要提及。
        3. 简洁明了：字数严格控制在200字以内，不要冗长，言简意赅。
        4. 重点介绍冰箱贴所代表的实体（如：灵隐寺、龙门石窟等），而不是冰箱贴本身。
        5. 直接返回科普内容，不要包含任何其他解释、前缀或“好的”、“没问题”之类的废话。
        """
        
        var userContentParts: [ContentPart] = [
            .init(type: "text", text: "名称：\(itemName)\n相关位置：\(location)\n采集日期：\(dateString)")
        ]
        
        if let image = image {
            let resizedImage = resizeImage(image, targetSize: CGSize(width: 1024, height: 1024))
            if let imageData = resizedImage.jpegData(compressionQuality: 0.6) {
                let base64Image = imageData.base64EncodedString()
                userContentParts.append(.init(type: "image_url", image_url: .init(url: "data:image/jpeg;base64,\(base64Image)")))
            }
        }
        
        let messages = [
            Message(role: "system", content: .text(systemPrompt)),
            Message(role: "user", content: .parts(userContentParts))
        ]
        
        return chatStream(messages: messages, modelType: modelType, temperature: 0.3)
    }
    
    func chat(messages: [Message], modelType: AIModelType) async throws -> String {
        var requestBody = ChatRequest(model: modelType.modelName, messages: messages)
        requestBody.max_tokens = 1024
        return try await performChatRequest(requestBody)
    }

    func chatStream(messages: [Message], modelType: AIModelType, temperature: Double = 0.7) -> AsyncThrowingStream<String, Error> {
        print("🌊 [AIService] Starting stream request. Model: \(modelType.modelName), Messages: \(messages.count)")
        let startTime = Date()
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: baseURL) else {
                        continuation.finish(throwing: AIServiceError.requestFailed("无效的 URL"))
                        return
                    }
                    
                    var requestBody = ChatRequest(model: modelType.modelName, messages: messages)
                    requestBody.temperature = temperature
                    requestBody.stream = true
                    requestBody.max_tokens = 1024
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(requestBody)
                    request.timeoutInterval = 120
                    
                    let (bytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        print("❌ [AIService] Stream request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                        continuation.finish(throwing: AIServiceError.requestFailed("服务器响应错误"))
                        return
                    }
                    
                    var tokenCount = 0
                    var firstTokenTime: Date?
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let dataString = line.replacingOccurrences(of: "data: ", with: "")
                            if dataString == "[DONE]" {
                                let duration = Date().timeIntervalSince(firstTokenTime ?? startTime)
                                let speed = duration > 0 ? Double(tokenCount) / duration : 0
                                print(String(format: "🏁 [AIService] Stream finished. 「tokens: %d, speed: %.2f tokens/s」", tokenCount, speed))
                                continuation.finish()
                                return
                            }
                            
                            if let data = dataString.data(using: .utf8),
                               let streamResponse = try? JSONDecoder().decode(ChatStreamResponse.self, from: data),
                               let content = streamResponse.choices.first?.delta.content {
                                if firstTokenTime == nil {
                                    firstTokenTime = Date()
                                    let latency = firstTokenTime!.timeIntervalSince(startTime)
                                    print(String(format: "✨ [AIService] First token received. Latency: %.2fs", latency))
                                }
                                
                                tokenCount += 1
                                if tokenCount % 20 == 0 {
                                    print("📥 [AIService] Received \(tokenCount) tokens...")
                                }
                                continuation.yield(content)
                            }
                        }
                    }
                    let duration = Date().timeIntervalSince(firstTokenTime ?? startTime)
                    let speed = duration > 0 ? Double(tokenCount) / duration : 0
                    print(String(format: "🏁 [AIService] Stream ended. 「tokens: %d, speed: %.2f tokens/s」", tokenCount, speed))
                    continuation.finish()
                } catch {
                    print("❌ [AIService] Stream error: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - TTS
    
    struct TTSRequest: Codable {
        let model: String
        let input: String
        let voice: String
        var response_format: String = "mp3"
    }
    
    func fetchTTSAudio(text: String) async throws -> Data {
        guard let url = URL(string: ttsURL) else {
            throw AIServiceError.requestFailed("无效的 TTS URL")
        }
        
        let requestBody = TTSRequest(
            model: "FunAudioLLM/CosyVoice2-0.5B",
            input: text,
            voice: "FunAudioLLM/CosyVoice2-0.5B:anna"
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.requestFailed("非 HTTP 响应")
        }
        
        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "未知错误"
            print("❌ [AIService] TTS request failed: \(errorMsg)")
            throw AIServiceError.requestFailed("TTS 请求失败: \(httpResponse.statusCode)")
        }
        
        return data
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
}
