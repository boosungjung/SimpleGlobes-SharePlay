//
//  ContentView.swift
//  SimpleGlobe
//
//  Created by Bernhard Jenny on 14/8/2024.
//

import SwiftUI
import RealityKit

struct ContentView: View {

    @Environment(ViewModel.self) var model

    var body: some View {
        VStack {
            #warning("pass Viewmodel configuration globe to globe button")
            GlobeButton(globe: ViewModel.shared.configuration.globe)
                .padding()
            SharePlayView()
        }
        .padding(50)
    }
}

//#Preview(windowStyle: .automatic) {
//    ContentView()
//        .environment(ViewModel.preview)
//}
