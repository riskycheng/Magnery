//
//  MagneryApp.swift
//  Magnery
//
//  Created by Jian Cheng on 2025/12/14.
//

import SwiftUI

@main
struct MagneryApp: App {
    @StateObject private var store = MagnetStore()
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
        }
    }
}
