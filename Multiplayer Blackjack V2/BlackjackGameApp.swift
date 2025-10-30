import SwiftUI
import RevenueCat
import UserNotifications

@main
struct BlackjackGameApp: App {
    init() {
        // Configure RevenueCat with your API key
        Purchases.configure(withAPIKey: "appl_ydFaWayhUaEJJcqFVgCxcfPDShE")
        // Enable debug logs for development (remove in production)
        Purchases.logLevel = .debug
        
        // Set notification delegate to show notifications even when app is active
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    var body: some Scene {
        WindowGroup {
            WelcomeView()
        }
    }
}
