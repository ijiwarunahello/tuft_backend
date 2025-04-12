//
//  ContentView.swift
//  agent_client_example
//
//  Created by Kazuya Iriguchi on 2025/04/12.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {

    var body: some View {
        //        VStack {
        //            Model3D(named: "Scene", bundle: realityKitContentBundle)
        //                .padding(.bottom, 50)
        //
        //            Text("Hello, world!")
        //
        //            ToggleImmersiveSpaceButton()
        //        }
        //        .padding()
        //    }
        ChatView()
    }
}

#Preview(windowStyle: .automatic) {
//    ContentView()
//        .environment(AppModel())
    ContentView()
}
