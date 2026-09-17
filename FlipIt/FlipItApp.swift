import SwiftUI

@main
struct FlipItApp: App {
    @StateObject private var store = FlipItStore()

    var body: some Scene {
        WindowGroup {
            HomeView(store: store)
                .environment(\.locale, Locale(identifier: store.settings.appLanguage.rawValue))
        }
    }
}
