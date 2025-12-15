//
//  KitAppApp.swift
//  KitApp
//
//  Created by Sakurai Erika on 2025/12/08.
//

import SwiftUI
import SwiftData

@main
struct KitAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: RouteRecord.self)
    }
}
