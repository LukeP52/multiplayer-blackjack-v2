import SwiftUI
import RevenueCat
import RevenueCatUI

struct WelcomeView: View {
    @StateObject private var game = BlackjackGame()
    @State private var showPaywall = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var destinationView: String?
    @State private var showCustomerCenter = false // New state for Customer Center
    
    var body: some View {
        NavigationStack {
            ZStack {
                Image("IMG_3879")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
                    .ignoresSafeArea()
                
                GeometryReader { geometry in
                    ZStack {
                        VStack(spacing: 40) {
                            Spacer()
                            
                            VStack(spacing: 4) {
                                Text("Blackjack")
                                    .font(.custom("Copperplate", size: 56))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                                Text("Ad-Free")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                            }
                            
                            Button(action: {
                                checkEntitlement(destination: "BlackjackView")
                            }) {
                                Text("Play")
                                    .font(.system(size: 28, weight: .heavy))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                                    .frame(width: 280, height: 70)
                                    .background(
                                        ZStack {
                                            Color.gold
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    .white.opacity(0.4),
                                                    .white.opacity(0.1),
                                                    .clear,
                                                    .black.opacity(0.1)
                                                ]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        }
                                    )
                                    .cornerRadius(20)
                                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            Button(action: {
                                checkEntitlement(destination: "PracticeView")
                            }) {
                                Text("Practice")
                                    .font(.system(size: 28, weight: .heavy))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                                    .frame(width: 280, height: 70)
                                    .background(
                                        ZStack {
                                            Color.richBlack
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    .white.opacity(0.4),
                                                    .white.opacity(0.1),
                                                    .clear,
                                                    .black.opacity(0.1)
                                                ]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        }
                                    )
                                    .cornerRadius(20)
                                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            Spacer()
                        }
                        
                        Button(action: {
                            showCustomerCenter = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                                .foregroundColor(.white)
                                .shadow(radius: 3)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .position(x: 50, y: 20)
                        .zIndex(100)
                    }
                }
                
                .navigationDestination(isPresented: $navigateToBlackjackView) {
                    BlackjackView(game: game).navigationBarBackButtonHidden(true)
                }
                .navigationDestination(isPresented: $navigateToPracticeView) {
                    PracticeView(blackjackGame: game).navigationBarBackButtonHidden(true)
                }
                
                .sheet(isPresented: $showCustomerCenter) {
                    CustomerCenterView()
                        .onDisappear {
                            // Reset all navigation state
                            navigateToBlackjackView = false
                            navigateToPracticeView = false
                            destinationView = nil
                            // Don't check entitlements on dismiss to prevent re-navigation
                        }
                }
                
                .sheet(isPresented: $showPaywall) {
                    PaywallView()
                        .onPurchaseCompleted { customerInfo in
                            if customerInfo.entitlements["Unlimited Play"]?.isActive == true {
                                showPaywall = false
                                if destinationView == "BlackjackView" {
                                    navigateToBlackjackView = true
                                } else if destinationView == "PracticeView" {
                                    navigateToPracticeView = true
                                }
                            }
                        }
                        .onRestoreCompleted { customerInfo in
                            if customerInfo.entitlements["Unlimited Play"]?.isActive == true {
                                showPaywall = false
                                if destinationView == "BlackjackView" {
                                    navigateToBlackjackView = true
                                } else if destinationView == "PracticeView" {
                                    navigateToPracticeView = true
                                }
                            } else {
                                errorMessage = "No active subscriptions found."
                                showErrorAlert = true
                            }
                        }
                }
                .alert("Error", isPresented: $showErrorAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(errorMessage)
                }
            }
        }
    }
    
    @State private var navigateToBlackjackView = false
    @State private var navigateToPracticeView = false
    
    private func checkEntitlement(destination: String) {
        destinationView = destination
        Purchases.shared.getCustomerInfo { customerInfo, error in
            if let error = error {
                errorMessage = error.localizedDescription
                showErrorAlert = true
                return
            }
            
            if customerInfo?.entitlements["Unlimited Play"]?.isActive == true {
                if destination == "BlackjackView" {
                    navigateToBlackjackView = true
                } else if destination == "PracticeView" {
                    navigateToPracticeView = true
                }
            } else {
                showPaywall = true
            }
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
}
