import SwiftUI
import RevenueCat

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var restoringPurchases = false
    @State private var restoreMessage = ""
    @State private var showRestoreAlert = false
    @State private var isSubscribed = false
    @State private var subscriptionInfo: String = "Checking..."
    @State private var showTimePicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.opacity(0.95)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Text("Settings")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Invisible placeholder for balance
                        Color.clear
                            .frame(width: 30, height: 30)
                    }
                    .padding()
                    
                    ScrollView {
                        VStack(spacing: 30) {
                            // Subscription Section
                            VStack(alignment: .leading, spacing: 15) {
                                Text("SUBSCRIPTION")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 0) {
                                    // Subscription Status
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Status")
                                                .font(.body)
                                                .foregroundColor(.white)
                                            Text(subscriptionInfo)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        if isSubscribed {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.05))
                                    
                                    Divider()
                                        .background(Color.gray.opacity(0.3))
                                    
                                    // Manage Subscription
                                    Button(action: {
                                        openAppleSubscriptionManagement()
                                    }) {
                                        HStack {
                                            Text("Manage Subscription")
                                                .foregroundColor(.white)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray)
                                                .font(.system(size: 14))
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.05))
                                    }
                                    
                                    Divider()
                                        .background(Color.gray.opacity(0.3))
                                    
                                    // Restore Purchases
                                    Button(action: {
                                        restorePurchases()
                                    }) {
                                        HStack {
                                            if restoringPurchases {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(0.8)
                                                    .padding(.trailing, 5)
                                            }
                                            Text("Restore Purchases")
                                                .foregroundColor(.white)
                                            Spacer()
                                            Image(systemName: "arrow.clockwise")
                                                .foregroundColor(.gray)
                                                .font(.system(size: 14))
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.05))
                                    }
                                    .disabled(restoringPurchases)
                                }
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }
                            
                            // Notifications Section
                            VStack(alignment: .leading, spacing: 15) {
                                Text("NOTIFICATIONS")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 0) {
                                    if !notificationManager.isAuthorized {
                                        // Permission request
                                        Button(action: {
                                            Task {
                                                await notificationManager.requestPermission()
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: "bell")
                                                    .foregroundColor(.white)
                                                Text("Enable Notifications")
                                                    .foregroundColor(.white)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 14))
                                            }
                                            .padding()
                                            .background(Color.white.opacity(0.05))
                                        }
                                    } else {
                                        // Daily Reminders
                                        HStack {
                                            Text("Daily Reminders")
                                                .foregroundColor(.white)
                                            Spacer()
                                            Toggle("", isOn: $notificationManager.dailyReminders)
                                                .onChange(of: notificationManager.dailyReminders) { _, _ in
                                                    notificationManager.saveSettings()
                                                }
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.05))
                                        
                                        if notificationManager.dailyReminders {
                                            Divider().background(Color.gray.opacity(0.3))
                                            
                                            Button(action: { showTimePicker = true }) {
                                                HStack {
                                                    Text("Reminder Time")
                                                        .foregroundColor(.white)
                                                    Spacer()
                                                    Text(notificationManager.preferredTime, style: .time)
                                                        .foregroundColor(.gray)
                                                    Image(systemName: "chevron.right")
                                                        .foregroundColor(.gray)
                                                        .font(.system(size: 14))
                                                }
                                                .padding()
                                                .background(Color.white.opacity(0.05))
                                            }
                                        }
                                        
                                    }
                                }
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 20)
                    }
                }
            }
        }
        .onAppear {
            checkSubscriptionStatus()
            notificationManager.checkAuthorizationStatus()
        }
        .sheet(isPresented: $showTimePicker) {
            NavigationView {
                VStack {
                    DatePicker("Reminder Time", selection: $notificationManager.preferredTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                        .padding()
                    
                    Spacer()
                }
                .navigationTitle("Reminder Time")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: Button("Cancel") { showTimePicker = false },
                    trailing: Button("Done") {
                        notificationManager.saveSettings()
                        showTimePicker = false
                    }
                )
            }
        }
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK") { }
        } message: {
            Text(restoreMessage)
        }
    }
    
    private func checkSubscriptionStatus() {
        Purchases.shared.getCustomerInfo { customerInfo, error in
            if let error = error {
                subscriptionInfo = "Error loading status"
                print("Error fetching customer info: \(error)")
                return
            }
            
            if let entitlement = customerInfo?.entitlements["Unlimited Play"], entitlement.isActive {
                isSubscribed = true
                
                // Get expiration date
                if let expirationDate = entitlement.expirationDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    subscriptionInfo = "Active until \(formatter.string(from: expirationDate))"
                } else {
                    subscriptionInfo = "Active"
                }
                
                // Add renewal info if available
                let productIdentifier = entitlement.productIdentifier
                if productIdentifier.contains("1mo") {
                    subscriptionInfo += " • Monthly"
                } else if productIdentifier.contains("1y") {
                    subscriptionInfo += " • Yearly"
                }
            } else {
                isSubscribed = false
                subscriptionInfo = "No active subscription"
            }
        }
    }
    
    private func restorePurchases() {
        restoringPurchases = true
        
        Purchases.shared.restorePurchases { customerInfo, error in
            restoringPurchases = false
            
            if let error = error {
                restoreMessage = "Restore failed: \(error.localizedDescription)"
                showRestoreAlert = true
                return
            }
            
            if customerInfo?.entitlements["Unlimited Play"]?.isActive == true {
                restoreMessage = "Purchases restored successfully!"
                checkSubscriptionStatus() // Refresh the status
            } else {
                restoreMessage = "No purchases found to restore."
            }
            showRestoreAlert = true
        }
    }
    
    private func openAppleSubscriptionManagement() {
        // Opens the subscription management page in Settings
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}