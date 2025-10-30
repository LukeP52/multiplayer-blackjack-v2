import Foundation
import UserNotifications
import SwiftUI

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var dailyReminders = false
    @Published var preferredTime = Date()
    
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadSettings()
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        dailyReminders = userDefaults.bool(forKey: "dailyReminders")
        
        if let timeData = userDefaults.data(forKey: "preferredTime"),
           let time = try? JSONDecoder().decode(Date.self, from: timeData) {
            preferredTime = time
        } else {
            // Default to 7 PM
            let calendar = Calendar.current
            preferredTime = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
        }
    }
    
    func saveSettings() {
        userDefaults.set(dailyReminders, forKey: "dailyReminders")
        
        if let timeData = try? JSONEncoder().encode(preferredTime) {
            userDefaults.set(timeData, forKey: "preferredTime")
        }
        
        updateScheduledNotifications()
    }
    
    // MARK: - Notification Scheduling
    
    private func updateScheduledNotifications() {
        // Cancel all existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        guard isAuthorized else { return }
        
        if dailyReminders {
            scheduleDailyReminder()
        }
    }
    
    private func scheduleDailyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Blackjack Time!"
        content.body = "Ready for your daily blackjack session?"
        content.sound = .default
        content.categoryIdentifier = "DAILY_REMINDER"
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: preferredTime)
        let minute = calendar.component(.minute, from: preferredTime)
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling daily reminder: \(error)")
            }
        }
    }
    
    
    
    // MARK: - Utility
    
    func openSystemSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}
