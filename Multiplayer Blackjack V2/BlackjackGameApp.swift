import SwiftUI
import RevenueCat

@main
struct BlackjackGameApp: App {
    init() {
        // Configure RevenueCat with your API key
        Purchases.configure(withAPIKey: "appl_ydFaWayhUaEJJcqFVgCxcfPDShE")
        // Enable debug logs for development (remove in production)
        Purchases.logLevel = .debug
    }
    
    var body: some Scene {
        WindowGroup {
            WelcomeView()
        }
    }
}
