import Foundation
import AVFoundation
import Speech
import Combine

class SpeechService: NSObject, ObservableObject, SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate {
    static let shared = SpeechService()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var isSpeaking = false
    
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 1.5 // Seconds of silence before auto-stopping
    
    override init() {
        super.init()
        speechRecognizer?.delegate = self
        synthesizer.delegate = self
        
        // Request permissions
        SFSpeechRecognizer.requestAuthorization { status in
            print("🎤 [SpeechService] Authorization status: \(status)")
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            print("🎤 [SpeechService] Record permission: \(granted)")
        }
    }
    
    // MARK: - TTS (Text to Speech)
    
    func speak(_ text: String) {
        stopSpeaking()
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
    
    // MARK: - ASR (Speech to Text)
    
    func startListening(completion: @escaping (String?) -> Void) {
        guard !isListening else { return }
        
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .defaultToSpeaker)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ [SpeechService] Audio session error: \(error)")
            completion(nil)
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else {
            completion(nil)
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        isListening = true
        recognizedText = ""
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                let newText = result.bestTranscription.formattedString
                
                DispatchQueue.main.async {
                    self.recognizedText = newText
                    
                    // Reset silence timer whenever new text is recognized
                    self.silenceTimer?.invalidate()
                    self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceThreshold, repeats: false) { _ in
                        print("🤫 [SpeechService] Silence detected, auto-stopping...")
                        self.stopListening()
                    }
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.silenceTimer?.invalidate()
                self.silenceTimer = nil
                
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                DispatchQueue.main.async {
                    self.isListening = false
                    if isFinal {
                        completion(self.recognizedText)
                    } else if error != nil {
                        print("❌ [SpeechService] Recognition error: \(error!)")
                        completion(nil)
                    }
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("❌ [SpeechService] Audio engine start error: \(error)")
            completion(nil)
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isListening = false
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}
