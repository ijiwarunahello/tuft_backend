// EnvironmentConfig.swift

import Foundation

struct EnvironmentConfig {
    static var baseURL: String {
        #if targetEnvironment(simulator)
        return "http://192.168.179.6:2024"  // Simulator用
        #else
        return UserDefaults.standard.string(forKey: "server_url") ?? "https://loyal-stinkbug-just.ngrok-free.app"  // 実機用（デフォルトIP）
        #endif
    }

    static func setServerURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: "server_url")
    }

    static func getServerURL() -> String {
        return UserDefaults.standard.string(forKey: "server_url") ?? "http://192.168.1.10:2024"
    }
}
