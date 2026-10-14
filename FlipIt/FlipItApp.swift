import SwiftUI

@main
struct FlipItApp: App {
    @StateObject private var store = FlipItStore()
    @StateObject private var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            HomeView(store: store)
                .environment(\.locale, Locale(identifier: store.settings.appLanguage.rawValue))
                .environmentObject(authManager)
                .onOpenURL { url in
                    Task {
                        await authManager.handleOpenURL(url)
                    }
                }
                .onAppear {
                    store.onMarketReviewReport = { shareCode, count, isReturn in
                        Task {
                            try? await SupabaseManager.shared.reportUsageStats(
                                shareCode: shareCode,
                                reviewsCount: count,
                                isReturnUser: isReturn
                            )
                        }
                    }
                }
        }
    }
}
