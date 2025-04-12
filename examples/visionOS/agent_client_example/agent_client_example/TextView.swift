//
//  TextView.swift
//  agent_client_example
//
//  Created by Kazuya Iriguchi on 2025/04/12.
//


import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let emotion: String?
    let metadata: [String: Any]?
}

struct ChatView: View {
    @State private var inputText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var threadId: String? = nil
    
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
            HStack {
                TextField("Type your message...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: 40)
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
                
                let messagesArray: [[String: Any]]?
                
                if let outputMessages = json["output"] as? [String: Any],
                   let msgs = outputMessages["messages"] as? [[String: Any]] {
                    messagesArray = msgs
                } else if let msgs = json["messages"] as? [[String: Any]] {
                    messagesArray = msgs
                } else {
                    print("Could not find messages array in response")
                    return
                }
                
                guard let responseMessages = messagesArray,
                      let lastAiMessage = responseMessages.last(where: { ($0["type"] as? String) == "ai" }) else {
                    print("No AI message found in response")
                    return
                }
                
                let content = lastAiMessage["content"] as? String ?? ""
                
                var metadata: [String: Any]? = nil
                var emotion: String? = nil
                
                if let additionalKwargs = lastAiMessage["additional_kwargs"] as? [String: Any],
                   let jsonData = additionalKwargs["json_data"] as? [String: Any] {
                    metadata = jsonData
                    emotion = jsonData["emotion"] as? String
                }
                
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
