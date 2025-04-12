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
                                Text(message.content + (message.emotion != nil ? " [\(message.emotion!)]" : ""))
                                    .padding(12)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
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
        
        let messageToSend = ChatMessage(role: "human", content: inputText, emotion: nil)
        messages.append(messageToSend)
        inputText = ""
        
        guard let url = URL(string: "\(EnvironmentConfig.baseURL)/threads/\(threadId)/runs/wait") else { return }
        
        let payload: [String: Any] = [
            "assistant_id": "agent",
            "input": [
                "messages": [
                    ["role": "human", "content": messageToSend.content]
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
            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let messageAtr = json["messages"] as? [[String: Any]] else {
                    print("Failed to parse response", error ?? "Unknown error")
                    return
            }
            
            let rawContent = messageAtr.last?["content"] as? String ?? ""
            let (assistantMessage, emotion): (String, String?)
            if let jsonString = rawContent
                .components(separatedBy: "```json")
                .last?
                .components(separatedBy: "```")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               let jsonData = jsonString.data(using: .utf8),
               let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let content = jsonDict["content"] as? String {
                assistantMessage = content
                emotion = jsonDict["emotion"] as? String
            } else {
                assistantMessage = rawContent
                emotion = nil
            }
            
            DispatchQueue.main.async {
                messages.append(ChatMessage(role: "assistant", content: assistantMessage, emotion: emotion))
            }
        }.resume()
    }
}
