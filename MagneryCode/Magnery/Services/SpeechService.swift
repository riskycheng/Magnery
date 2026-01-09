import Foundation
import AVFoundation
import Speech
import Combine

class SpeechService: NSObject, ObservableObject, SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    static let shared = SpeechService()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var audioQueue: [Data] = []
    private var isPlayingQueue = false
    
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
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }
    
    // MARK: - TTS (Text to Speech)
    
    func speak(_ text: String, useSiliconFlow: Bool = true) {
        if useSiliconFlow {
            Task {
                do {
                    let data = try await AIService.shared.fetchTTSAudio(text: text)
                    await MainActor.run {
                        self.playAudioData(data)
                    }
                } catch {
                    print("❌ [SpeechService] SiliconFlow TTS failed, falling back to system: \(error)")
                    await MainActor.run {
                        self.speakSystem(text)
                    }
                }
            }
        } else {
            speakSystem(text)
        }
    }
    
    private func speakSystem(_ text: String) {
        stopSpeaking()
        configureAudioSession(forPlayback: true)
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    func playAudioData(_ data: Data) {
        stopSpeaking()
        configureAudioSession(forPlayback: true)
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0 // Ensure max volume
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isSpeaking = true
        } catch {
            print("❌ [SpeechService] Audio player error: \(error)")
        }
    }
    
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if let player = audioPlayer, player.isPlaying {
            player.stop()
        }
        audioPlayer = nil
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
        configureAudioSession(forPlayback: false)
        
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
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
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
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.playNextInQueue()
        }
    }
    
    // MARK: - Streaming TTS Queue
    
    func enqueueAndPlay(_ text: String) {
        Task {
            do {
                let data = try await AIService.shared.fetchTTSAudio(text: text)
                await MainActor.run {
                    self.audioQueue.append(data)
                    if !self.isPlayingQueue {
                        self.playNextInQueue()
                    }
                }
            } catch {
                print("❌ [SpeechService] Streaming TTS failed, falling back to system: \(error)")
                await MainActor.run {
                    self.speakSystem(text)
                }
            }
        }
    }
    
    private func playNextInQueue() {
        guard !audioQueue.isEmpty else {
            isPlayingQueue = false
            return
        }
        
        isPlayingQueue = true
        configureAudioSession(forPlayback: true)
        let data = audioQueue.removeFirst()
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isSpeaking = true
        } catch {
            print("❌ [SpeechService] Queue player error: \(error)")
            playNextInQueue()
        }
    }
    
    func clearQueue() {
        audioQueue.removeAll()
        stopSpeaking()
        isPlayingQueue = false
    }
    
    // MARK: - Audio Session Management
    
    private func configureAudioSession(forPlayback: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if forPlayback {
                // .defaultToSpeaker is only for .playAndRecord. 
                // .playback automatically uses speakers/headphones.
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            } else {
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            }
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ [SpeechService] Failed to configure audio session: \(error)")
        }
    }
}
