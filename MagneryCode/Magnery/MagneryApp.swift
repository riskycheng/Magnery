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
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    
    var body: some Scene {
        WindowGroup {
            if !hasCompletedOnboarding {
                OnboardingView()
                    .environmentObject(store)
            } else {
                MainTabView()
                    .environmentObject(store)
            }
        }
    }
}
