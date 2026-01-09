import Foundation
import Network
import SwiftUI
import Combine

enum AIModelType: String, CaseIterable {
    case standard = "标准"
    case professional = "专业"
    case advanced = "高级"
    
    var modelName: String {
        switch self {
        case .standard:
            return "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B"
        case .professional:
            return "deepseek-ai/DeepSeek-R1-Distill-Qwen-14B"
        case .advanced:
            return "Pro/deepseek-ai/DeepSeek-R1"
        }
    }
    
    var features: (icon: String, title: String, description: String) {
        switch self {
        case .standard:
            return ("bolt", "简洁高效", "快速分析决策选项，提供简明有效的建议")
        case .professional:
            return ("chart.bar.xaxis", "精准科学", "科学量化各种因素，提供精准深入的决策依据")
        case .advanced:
            return ("brain.head.profile", "思考可视化", "实时展示AI思考过程，提供全面透明的决策建议")
        }
    }
    
    var supportsStreaming: Bool {
        return self == .advanced
    }
}

class AIService: ObservableObject, @unchecked Sendable {
    private let apiKey = "sk-ezwzqwedwhtnbyitbnyohvzanpitqqlnpjucejddpozmpjxj"  // DeepSeek API Key
    private let baseURL = "https://api.siliconflow.cn/v1/chat/completions"
    private let monitor = NWPathMonitor()
    private var isNetworkAvailable = true
    @AppStorage("aiModelType") var aiModelType: String = AIModelType.advanced.rawValue
    
    // 流式分析状态
    @Published var isStreaming = false
    @Published var streamedThinkingSteps: [String] = []
    @Published var streamingComplete = false
    @Published var isSummarizing = false // 正在总结结果的状态
    @Published var finalAnswer: String = "" // 最终答案
    private var streamingTask: Task<Void, Never>? = nil
    private var cancellables = Set<AnyCancellable>()
    
    enum AIServiceError: Error {
        case networkNotAvailable
        case requestFailed(String)
        case invalidResponse
        case parseError
        case serverBusy
        
        var localizedDescription: String {
            switch self {
            case .networkNotAvailable:
                return "网络连接不可用，请检查网络设置后重试"
            case .requestFailed(let message):
                return "请求失败：\(message)"
            case .invalidResponse:
                return "服务器响应无效，请稍后重试"
            case .parseError:
                return "AI响应格式错误，请稍后重试"
            case .serverBusy:
                return "服务器当前繁忙，请稍后重试"
            }
        }
    }
    
    init() {
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = path.status == .satisfied
        }
        monitor.start(queue: DispatchQueue.global())
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
    
    struct ChatRequest: Codable {
        let model: String
        let messages: [Message]
        let stream: Bool
        let max_tokens: Int
        let temperature: Double
        let top_p: Double
        let top_k: Int
        let frequency_penalty: Double
        let n: Int
    }
    
    struct Choice: Codable {
        let message: Message
        let finish_reason: String?
    }
    
    struct ChatResponse: Codable {
        let choices: [Choice]
    }
    
    // 流式响应结构
    struct StreamChoice: Codable {
        struct Delta: Codable {
            let content: String?
            let reasoning_content: String?
        }
        let delta: Delta
        let finish_reason: String?
    }
    
    struct StreamResponse: Codable {
        let choices: [StreamChoice]
    }
    
    func analyzeDecision(_ decision: Decision) async throws -> Decision.Result {
        // 检查网络状态
        guard isNetworkAvailable else {
            throw AIServiceError.networkNotAvailable
        }
        
        // 获取当前选择的模型类型
        let modelType = AIModelType(rawValue: aiModelType) ?? .professional
        
        // 如果是高级模式，使用流式分析
        if modelType == .advanced {
            return try await analyzeDecisionWithStreaming(decision)
        } else {
            return try await analyzeDecisionStandard(decision)
        }
    }
    
    private func getSystemPrompt(isStreaming: Bool) -> String {
        if isStreaming {
            return """
            你是一个专业的决策分析助手。请基于用户提供的信息，分析两个选项并给出建议。
            请在回答问题时，先展示你的思考过程，然后再给出最终答案。请一步一步详细思考。
            
            你需要：
            1. 分析每个选项的优点和缺点
            2. 给出最终推荐（用A表示第一个选项，用B表示第二个选项）
            3. 给出推荐的置信度（0-1之间的小数）
            4. 提供详细的分析理由
            
            请确保最终回复格式如下：
            {
                "recommendation": "A或B",
                "confidence": 0.75,
                "reasoning": "详细的分析理由",
                "prosA": ["优点1", "优点2", ...],
                "consA": ["缺点1", "缺点2", ...],
                "prosB": ["优点1", "优点2", ...],
                "consB": ["缺点1", "缺点2", ...]
            }
            
            注意：必须严格按照上述JSON格式返回，不要添加任何其他内容。
            """
        } else {
            return """
            你是一个专业的决策分析助手。请基于用户提供的信息，分析两个选项并给出建议。
            你需要：
            1. 分析每个选项的优点和缺点
            2. 给出最终推荐（用A表示第一个选项，用B表示第二个选项）
            3. 给出推荐的置信度（0-1之间的小数）
            4. 提供详细的分析理由
            
            请确保回复格式如下：
            {
                "recommendation": "A或B",
                "confidence": 0.75,
                "reasoning": "详细的分析理由",
                "prosA": ["优点1", "优点2", ...],
                "consA": ["缺点1", "缺点2", ...],
                "prosB": ["优点1", "优点2", ...],
                "consB": ["缺点1", "缺点2", ...]
            }
            
            注意：必须严格按照上述JSON格式返回，不要添加任何其他内容。
            """
        }
    }
    
    private func analyzeDecisionStandard(_ decision: Decision) async throws -> Decision.Result {
        let systemPrompt = getSystemPrompt(isStreaming: false)
        
        let userPrompt = """
        决策标题：\(decision.title)
        
        选项A：\(decision.options[0].title)
        选项A描述：\(decision.options[0].description)
        
        选项B：\(decision.options[1].title)
        选项B描述：\(decision.options[1].description)
        
        补充信息：\(decision.additionalInfo.isEmpty ? "无" : decision.additionalInfo)
        重要程度：\(decision.importance)/5
        决策时间框架：\(decision.timeFrame.rawValue)
        决策类型：\(decision.decisionType.rawValue)
        """
        
        let messages = [
            Message(role: "system", content: systemPrompt),
            Message(role: "user", content: userPrompt)
        ]
        
        // 获取当前选择的模型类型
        let modelType = AIModelType(rawValue: aiModelType) ?? .professional
        
        let request = ChatRequest(
            model: modelType.modelName,
            messages: messages,
            stream: false,
            max_tokens: 1024,
            temperature: 0.7,
            top_p: 0.7,
            top_k: 50,
            frequency_penalty: 0.5,
            n: 1
        )
        
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            
            // 检查HTTP状态码
            switch httpResponse.statusCode {
            case 200:
                break // 继续处理
            case 429:
                throw AIServiceError.serverBusy
            case 500...599:
                throw AIServiceError.serverBusy
            default:
                throw AIServiceError.requestFailed("HTTP状态码: \(httpResponse.statusCode)")
            }
            
            let apiResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
            
            guard let resultString = apiResponse.choices.first?.message.content else {
                throw AIServiceError.invalidResponse
            }
            
            // 清理 JSON 字符串，移除代码块标记
            let cleanedString = resultString
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let resultData = cleanedString.data(using: .utf8) else {
                throw AIServiceError.invalidResponse
            }
            
            do {
                let result = try JSONDecoder().decode(Decision.Result.self, from: resultData)
                return result
            } catch {
                print("解析错误: \(error)")
                print("AI返回内容: \(resultString)")
                throw AIServiceError.parseError
            }
        } catch {
            if let aiError = error as? AIServiceError {
                throw aiError
            }
            throw AIServiceError.requestFailed(error.localizedDescription)
        }
    }
    
    // 流式分析方法
    private func analyzeDecisionWithStreaming(_ decision: Decision) async throws -> Decision.Result {
        // 重置流式状态
        await MainActor.run {
            self.isStreaming = true
            self.streamedThinkingSteps = []
            self.streamingComplete = false
        }
        
        let systemPrompt = getSystemPrompt(isStreaming: true)
        
        let userPrompt = """
        决策标题：\(decision.title)
           
        选项A：\(decision.options[0].title)
        选项A描述：\(decision.options[0].description)
        
        选项B：\(decision.options[1].title)
        选项B描述：\(decision.options[1].description)
        
        补充信息：\(decision.additionalInfo.isEmpty ? "无" : decision.additionalInfo)
        重要程度：\(decision.importance)/5
        决策时间框架：\(decision.timeFrame.rawValue)
        决策类型：\(decision.decisionType.rawValue)
        """
        
        let messages = [
            Message(role: "system", content: systemPrompt),
            Message(role: "user", content: userPrompt)
        ]
        
        // 获取当前选择的模型类型
        let modelType = AIModelType(rawValue: aiModelType) ?? .professional
        
        let request = ChatRequest(
            model: modelType.modelName,
            messages: messages,
            stream: true,
            max_tokens: 2048,  // 增加token限制以容纳思考过程
            temperature: 0.7,
            top_p: 0.7,
            top_k: 50,
            frequency_penalty: 0.5,
            n: 1
        )
        
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        // 创建一个Future来处理最终结果
        return try await withCheckedThrowingContinuation { continuation in
            var fullContent = ""
            var fullReasoning = ""
            
            // 取消之前的任务
            streamingTask?.cancel()
            
            // 创建新的流式处理任务
            streamingTask = Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AIServiceError.invalidResponse
                    }
                    
                    // 检查HTTP状态码
                    switch httpResponse.statusCode {
                    case 200:
                        break // 继续处理
                    case 429:
                        throw AIServiceError.serverBusy
                    case 500...599:
                        throw AIServiceError.serverBusy
                    default:
                        throw AIServiceError.requestFailed("HTTP状态码: \(httpResponse.statusCode)")
                    }
                    
                    // 处理流式响应
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        
                        // 跳过空行和[DONE]标记
                        if line.isEmpty || line == "data: [DONE]" { continue }
                        
                        // 处理数据行
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            do {
                                let streamResponse = try JSONDecoder().decode(StreamResponse.self, from: jsonString.data(using: .utf8)!)
                                
                                if let choice = streamResponse.choices.first {
                                    // 处理内容更新
                                    if let content = choice.delta.content {
                                        fullContent += content
                                    }
                                    
                                    // 处理思考过程更新
                                    if let reasoning = choice.delta.reasoning_content, !reasoning.isEmpty {
                                        fullReasoning += reasoning
                                        
                                        // 打印思考过程到控制台
                                        print("[思考过程]: \(reasoning)")
                                        
                                        // 更新UI显示的思考步骤
                                        DispatchQueue.main.async { [weak self] in
                                            self?.streamedThinkingSteps.append(reasoning)
                                            
                                            // 通知观察者数据已更新
                                            self?.objectWillChange.send()
                                        }
                                    }
                                    
                                    // 检查是否完成
                                    if choice.finish_reason != nil {
                                        DispatchQueue.main.async { [weak self] in
                                            self?.streamingComplete = true
                                        }
                                    }
                                }
                            } catch {
                                // 忽略解析错误，继续处理下一行
                                continue
                            }
                        }
                    }
                    
                    // 流式传输完成后，进入总结阶段
                    DispatchQueue.main.async { [weak self] in
                        // 使用动画过渡到总结状态
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self?.isSummarizing = true
                            self?.finalAnswer = "AI正在总结分析结果..."
                        }
                        
                        // 发送通知以触发可能的视觉反馈
                        self?.objectWillChange.send()
                    }
                    
                    // 等待短暂时间，显示总结状态，增加时间以提供更好的视觉反馈
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5秒
                    
                    // 清理JSON字符串，处理常见格式问题
                    var cleanedString = fullContent
                        .replacingOccurrences(of: "```json", with: "")
                        .replacingOccurrences(of: "```", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    print("Original JSON string: \(cleanedString)")
                    
                    // 使用更健壮的方法解析JSON
                    do {
                        // 首先尝试直接解析，看是否是有效的JSON
                        let _ = try JSONSerialization.jsonObject(with: cleanedString.data(using: .utf8) ?? Data(), options: [])
                        // 如果能成功解析，就使用原始字符串
                        print("JSON is already valid, no sanitization needed")
                    } catch {
                        print("Invalid JSON, attempting to sanitize: \(error.localizedDescription)")
                        
                        // 第一步：标准化引号 - 将所有单引号替换为双引号
                        var sanitizedString = cleanedString.replacingOccurrences(of: "'", with: "\"")
                        
                        // 第二步：修复嵌套引号问题 - 先标记所有JSON键的双引号
                        let jsonKeyPattern = "\"(recommendation|confidence|reasoning|prosA|consA|prosB|consB)\"\\s*:"
                        if let regex = try? NSRegularExpression(pattern: jsonKeyPattern) {
                            let range = NSRange(sanitizedString.startIndex..., in: sanitizedString)
                            let matches = regex.matches(in: sanitizedString, range: range)
                            
                            // 从后向前替换，避免位置偏移
                            for match in matches.reversed() {
                                if let keyRange = Range(match.range, in: sanitizedString) {
                                    let key = sanitizedString[keyRange]
                                    // 用特殊标记替换JSON键中的双引号
                                    let markedKey = String(key).replacingOccurrences(of: "\"", with: "__QUOTE__")
                                    sanitizedString.replaceSubrange(keyRange, with: markedKey)
                                }
                            }
                        }
                        
                        // 第三步：处理数组中的嵌套引号
                        // 找到所有数组
                        let arrayPattern = "\\[([^\\[\\]]*)\\]"
                        if let regex = try? NSRegularExpression(pattern: arrayPattern) {
                            let range = NSRange(sanitizedString.startIndex..., in: sanitizedString)
                            let matches = regex.matches(in: sanitizedString, range: range)
                            
                            for match in matches.reversed() {
                                if let arrayRange = Range(match.range(at: 1), in: sanitizedString),
                                   let fullRange = Range(match.range, in: sanitizedString) {
                                    let arrayContent = sanitizedString[arrayRange]
                                    // 分割数组元素
                                    let elements = String(arrayContent).components(separatedBy: ",")
                                    let processedElements = elements.map { element -> String in
                                        let trimmed = element.trimmingCharacters(in: .whitespacesAndNewlines)
                                        // 如果元素没有用双引号包围，则添加双引号
                                        if !trimmed.hasPrefix("\"") || !trimmed.hasSuffix("\"") {
                                            return "\"\(trimmed.replacingOccurrences(of: "\"", with: ""))\"" 
                                        }
                                        return trimmed
                                    }
                                    // 重建数组
                                    sanitizedString.replaceSubrange(fullRange, with: "[\(processedElements.joined(separator: ","))]")
                                }
                            }
                        }
                        
                        // 第四步：处理reasoning字段中的嵌套引号和特殊字符
                        let reasoningPattern = "\"reasoning\"\\s*:\\s*\"([^\\\"]*)\""
                        if let regex = try? NSRegularExpression(pattern: reasoningPattern) {
                            let range = NSRange(sanitizedString.startIndex..., in: sanitizedString)
                            if let match = regex.firstMatch(in: sanitizedString, range: range),
                               let textRange = Range(match.range(at: 1), in: sanitizedString),
                               let fullRange = Range(match.range, in: sanitizedString) {
                                let text = sanitizedString[textRange]
                                // 转义reasoning中的所有双引号
                                let escapedText = String(text).replacingOccurrences(of: "\"", with: "\\\"")
                                // 重建reasoning字段
                                sanitizedString.replaceSubrange(fullRange, with: "\"reasoning\":\"\(escapedText)\"")
                            }
                        }
                        
                        // 第五步：恢复JSON键中的双引号标记
                        sanitizedString = sanitizedString.replacingOccurrences(of: "__QUOTE__", with: "\"")
                        
                        // 第六步：确保所有数组元素都用双引号包围
                        let arrayElementPattern = "\\[([^\\[\\]]*)\\]"
                        if let regex = try? NSRegularExpression(pattern: arrayElementPattern) {
                            let range = NSRange(sanitizedString.startIndex..., in: sanitizedString)
                            let matches = regex.matches(in: sanitizedString, range: range)
                            
                            for match in matches.reversed() {
                                if let arrayRange = Range(match.range(at: 1), in: sanitizedString),
                                   let fullRange = Range(match.range, in: sanitizedString) {
                                    let arrayContent = sanitizedString[arrayRange]
                                    // 分割数组元素
                                    let elements = String(arrayContent).components(separatedBy: ",")
                                    let processedElements = elements.map { element -> String in
                                        let trimmed = element.trimmingCharacters(in: .whitespacesAndNewlines)
                                        // 如果元素没有用双引号包围，则添加双引号
                                        if !trimmed.hasPrefix("\"") || !trimmed.hasSuffix("\"") {
                                            return "\"\(trimmed.replacingOccurrences(of: "\"", with: ""))\"" 
                                        }
                                        return trimmed
                                    }
                                    // 重建数组
                                    sanitizedString.replaceSubrange(fullRange, with: "[\(processedElements.joined(separator: ","))]")
                                }
                            }
                        }
                        
                        // 保存处理后的JSON字符串
                        cleanedString = sanitizedString
                        print("Reconstructed JSON: \(cleanedString)")
                        
                        // 如果仍然无法解析，使用默认结果
                        let defaultResult = "{"
                        + "\"recommendation\": \"A\","
                        + "\"confidence\": 0.5,"
                        + "\"reasoning\": \"JSON解析错误，请重新分析\","
                        + "\"prosA\": [\"JSON解析错误\"],"
                        + "\"consA\": [\"JSON解析错误\"],"
                        + "\"prosB\": [\"JSON解析错误\"],"
                        + "\"consB\": [\"JSON解析错误\"]"
                        + "}"
                        
                        guard let defaultData = defaultResult.data(using: .utf8) else {
                            throw AIServiceError.invalidResponse
                        }
                        
                        var defaultResultObj = try JSONDecoder().decode(Decision.Result.self, from: defaultData)
                        defaultResultObj.thinkingProcess = fullReasoning
                        continuation.resume(returning: defaultResultObj)
                        return
                    }
                    
                    // 尝试解析清理后的JSON
                    guard let resultData = cleanedString.data(using: .utf8) else {
                        throw AIServiceError.invalidResponse
                    }
                    
                    do {
                        var result = try JSONDecoder().decode(Decision.Result.self, from: resultData)
                        
                        // 保存思考过程
                        result.thinkingProcess = fullReasoning
                        
                        // 生成最终答案摘要
                        let option = result.recommendation == "A" ? decision.options[0].title : decision.options[1].title
                        let confidence = Int(result.confidence * 100)
                        let finalAnswerText = "\(result.recommendation == "A" ? "选项A" : "选项B"): \(option) (置信度: \(confidence)%)"
                        
                        // 更新UI状态
                        DispatchQueue.main.async { [weak self] in
                            self?.finalAnswer = finalAnswerText
                            self?.isStreaming = false
                            self?.isSummarizing = false
                            self?.streamingComplete = true
                        }
                        
                        // 返回结果
                        continuation.resume(returning: result)
                    } catch {
                        print("解析错误: \(error)")
                        print("AI返回内容: \(fullContent)")
                        continuation.resume(throwing: AIServiceError.parseError)
                    }
                } catch {
                    // 更新UI状态
                    DispatchQueue.main.async { [weak self] in
                        self?.isStreaming = false
                    }
                    
                    if let aiError = error as? AIServiceError {
                        continuation.resume(throwing: aiError)
                    } else {
                        continuation.resume(throwing: AIServiceError.requestFailed(error.localizedDescription))
                    }
                }
            }
        }
    }
    
    // 取消流式分析
    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        
        DispatchQueue.main.async {
            self.isStreaming = false
            self.isSummarizing = false
            self.streamingComplete = true
        }
    }
} 
