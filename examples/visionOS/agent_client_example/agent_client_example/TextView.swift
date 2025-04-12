//
//  TextView.swift
//  agent_client_example
//
//  Created by Kazuya Iriguchi on 2025/04/12.
//


import SwiftUI
import Speech

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let emotion: String?
    let metadata: [String: Any]?
}

// 音声認識を行うクラス
final class SpeechAnalyzer: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var recognizedText: String?
    @Published var isProcessing: Bool = false

    func start() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Couldn't configure the audio session properly")
        }
        
        inputNode = audioEngine.inputNode
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP")) // 日本語認識
        print("Supports on device recognition: \(speechRecognizer?.supportsOnDeviceRecognition == true ? "✅" : "🔴")")

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable,
              let recognitionRequest = recognitionRequest,
              let inputNode = inputNode
        else {
            assertionFailure("Unable to start the speech recognition!")
            return
        }
        
        speechRecognizer.delegate = self
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            recognitionRequest.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.recognizedText = result?.bestTranscription.formattedString
            
            guard error != nil || result?.isFinal == true else { return }
            self?.stop()
        }

        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isProcessing = true
        } catch {
            print("Coudn't start audio engine!")
            stop()
        }
    }
    
    func stop() {
        recognitionTask?.cancel()
        
        self.audioEngine.stop()
        inputNode?.removeTap(onBus: 0)
        
        isProcessing = false
        
        recognitionRequest = nil
        recognitionTask = nil
        speechRecognizer = nil
        inputNode = nil
    }
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            print("✅ Available")
        } else {
            print("🔴 Unavailable")
            recognizedText = "Text recognition unavailable. Sorry!"
            stop()
        }
    }
}

struct ChatView: View {
    @State private var inputText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var threadId: String? = nil
    @StateObject private var speechAnalyzer = SpeechAnalyzer()
    
    private let buttonSize: CGFloat = 44
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        HStack {
                            if message.role == "human" {
                                Spacer()
                                Text(message.content)
                                    .padding(12)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                            } else {
                                VStack(alignment: .leading) {
                                    Text(message.content + (message.emotion != nil ? " [\(message.emotion!)]" : ""))
                                        .padding(12)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                    
                                    if let metadata = message.metadata, !metadata.isEmpty {
                                        HStack {
                                            ForEach(Array(metadata.keys), id: \.self) { key in
                                                if key != "emotion" {
                                                    Text("\(key): \(String(describing: metadata[key] ?? ""))")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                        }
                                        .padding(.leading, 12)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .padding()
            }
            
            // 音声認識結果の表示
            if speechAnalyzer.isProcessing {
                Text(speechAnalyzer.recognizedText ?? "聞いています...")
                    .padding()
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(8)
            }
            
            HStack {
                // テキスト入力フィールド
                TextField("Type your message...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: 40)
                    .onChange(of: speechAnalyzer.recognizedText) { _, newValue in
                        if let text = newValue {
                            inputText = text
                        }
                    }
                
                // 音声認識ボタン
                Button(action: {
                    toggleSpeechRecognition()
                }) {
                    Image(systemName: speechAnalyzer.isProcessing ? "waveform.circle.fill" : "waveform.circle")
                        .resizable()
                        .frame(width: buttonSize, height: buttonSize)
                        .foregroundColor(speechAnalyzer.isProcessing ? .red : .gray)
                        .aspectRatio(contentMode: .fit)
                }
                .padding(.horizontal, 4)
                
                // 送信ボタン
                Button(action: {
                    sendMessage()
                }) {
                    Text("Send")
                        .padding(.horizontal)
                }
                .disabled(inputText.isEmpty)
            }
            .padding()
        }
        .onAppear {
            createThread()
            requestSpeechAuthorization()
        }
    }
    
    // Speech認識の許可リクエスト
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition not available: \(status.rawValue)")
                @unknown default:
                    print("Unknown speech recognition authorization status")
                }
            }
        }   
    }
    
    // 音声認識の開始/停止を切り替え
    private func toggleSpeechRecognition() {
        if speechAnalyzer.isProcessing {
            speechAnalyzer.stop()
            // 音声認識が停止しても、認識したテキストは保持する
            // ここでinputTextをクリアしないようにする
        } else {
            speechAnalyzer.start()
        }
    }
    
    func createThread() {
        guard let url = URL(string: "\(EnvironmentConfig.baseURL)/threads") else { return }
        let payload = ["metadata": ["purpose": "conversation"]]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let threadId = json["thread_id"] as? String
            else {
                print("Failed to parse thread ID", error ?? "Unknown error")
                return
            }
            DispatchQueue.main.async {
                self.threadId = threadId
            }
        }.resume()
    }
    
    func sendMessage() {
        guard let threadId = threadId else { return }
        
        // 音声認識中なら停止
        if speechAnalyzer.isProcessing {
            speechAnalyzer.stop()
        }
        
        let messageToSend = ChatMessage(role: "human", content: inputText, emotion: nil, metadata: nil)
        messages.append(messageToSend)
        inputText = ""
        
        guard let url = URL(string: "\(EnvironmentConfig.baseURL)/threads/\(threadId)/runs/wait") else { return }
        
        let payload: [String: Any] = [
            "assistant_id": "agent",
            "input": [
                "messages": [
                    ["role": "human", "content": messageToSend.content]
                ]
            ],
            "config": [
                "configurable": [
                    "response_model_extras": [
                        "timestamp": "auto",
                        "version": "1.0"
                    ]
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard
                let data = data else {
                    print("No data received", error ?? "Unknown error")
                    return
                
            }
            print("Response data: \(String(data: data, encoding: .utf8) ?? "Failed to convert data to string")")
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("Failed to parse JSON response")
                    return
                }
                
                // エラーチェック
                if let errorDict = json["__error__"] as? [String: Any],
                   let errorMessage = errorDict["message"] as? String {
                    print("Server error: \(errorMessage)")
                    DispatchQueue.main.async {
                        self.messages.append(ChatMessage(
                            role: "assistant",
                            content: "エラーが発生しました: \(errorMessage)",
                            emotion: "sad",
                            metadata: nil
                        ))
                    }
                    return
                }
                
                // レスポンスの解析（実際のレスポンス構造に合わせて修正）
                let messagesArray: [[String: Any]]?
                
                // レスポンス構造の可能性をチェック
                if let outputMessages = json["output"] as? [String: Any],
                   let msgs = outputMessages["messages"] as? [[String: Any]] {
                    // output.messages 構造の場合
                    messagesArray = msgs
                } else if let msgs = json["messages"] as? [[String: Any]] {
                    // フラットなmessages構造の場合
                    messagesArray = msgs
                } else {
                    print("Could not find messages array in response")
                    return
                }
                
                // 最後のメッセージ（AIからの応答）を取得
                guard let responseMessages = messagesArray,
                      let lastAiMessage = responseMessages.last(where: { ($0["type"] as? String) == "ai" }) else {
                    print("No AI message found in response")
                    return
                }
                
                // メッセージの内容を取得
                let content = lastAiMessage["content"] as? String ?? ""
                
                // メタデータを取得
                var metadata: [String: Any]? = nil
                var emotion: String? = nil
                
                // additional_kwargsからjson_dataを取得
                if let additionalKwargs = lastAiMessage["additional_kwargs"] as? [String: Any],
                   let jsonData = additionalKwargs["json_data"] as? [String: Any] {
                    metadata = jsonData
                    emotion = jsonData["emotion"] as? String
                }
                
                // レガシー形式のサポート（後方互換性）
                if emotion == nil && content.contains("```json") {
                    if let jsonString = content.components(separatedBy: "```json")
                        .last?
                        .components(separatedBy: "```")
                        .first?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                       let jsonData = jsonString.data(using: .utf8),
                       let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        
                        emotion = jsonDict["emotion"] as? String
                        if metadata == nil {
                            metadata = jsonDict
                        }
                    }
                }
                
                print("Parsed content: \(content)")
                print("Parsed emotion: \(emotion ?? "none")")
                print("Parsed metadata: \(metadata ?? [:])")
                
                // メインスレッドでUIを更新
                DispatchQueue.main.async {
                    self.messages.append(ChatMessage(
                        role: "assistant",
                        content: content,
                        emotion: emotion,
                        metadata: metadata
                    ))
                }
            } catch {
                print("Error parsing response: \(error)")
            }
        }.resume()
    }
}
