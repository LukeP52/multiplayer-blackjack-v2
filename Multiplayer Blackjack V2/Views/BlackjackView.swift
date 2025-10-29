import SwiftUI

// Custom color for green felt
extension Color {
    static let greenFelt = Color(red: 61/255, green: 107/255, blue: 61/255) // #3D6B3D
}

// Add these color extensions
extension Color {
    static let silver = Color(red: 192/255, green: 192/255, blue: 192/255)
    static let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
    static let darkGold = Color(red: 184/255, green: 134/255, blue: 11/255)
    static let richRed = Color(red: 178/255, green: 34/255, blue: 34/255)
    static let richBlack = Color(red: 20/255, green: 20/255, blue: 20/255)
}

struct BlackjackView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var game: BlackjackGame
    @State private var showingQuitAlert = false
    @State private var showPlayerTurnButtons = false
    @State private var flippedCards: Set<UUID> = []
    @State private var handNotificationOpacities: [Int: Double] = [:]
    @State private var pendingNotifications: [Int: String] = [:]
    @State private var flippedCardCounts: [Int: Int] = [:]
    @State private var insuranceNotificationOpacity: Double = 0
    @State private var showResolutionButtons = false
    @State private var isPlaceBetDisabled = false
    @State private var isInitialAppearance = true
    @State private var isSlidingOut = false
    @State private var isRepeatBetDisabled = false
    @State private var isChangeBetDisabled = false
    @State private var showHandTotals = true
    @State private var bettingUIOffset: CGFloat = 500
    @State private var showInfoView = false

    var body: some View {
        ZStack {
            // Background (green felt)
            Image("IMG_3879")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            // Info Button (in its own ZStack layer)
            GeometryReader { geometry in
                Button(action: {
                    showInfoView = true
                }) {
                    Image(systemName: "info.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.top, -10)
                .padding(.leading, 100)
                .zIndex(100)  // Ensure it's above other elements
            }

            // Main game content
            GeometryReader { geometry in
                ZStack {
                    VStack {
                        Spacer()
                            .frame(height: geometry.size.height * 0.05)
                        Text("$\(game.state.playerBalance)")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .frame(height: 40)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.2)

                        // Game content
                        VStack {
                            Spacer()
                                .frame(height: geometry.size.height * 0.08)
                            dealingView
                            Spacer()
                        }
                        .padding()
                        .blur(radius: game.isReshuffling ? 10 : 0)
                        .allowsHitTesting(!game.isReshuffling)
                    }
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.28)

                    // Progress bar
                    let progress = min(CGFloat(game.state.handsPlayed) / 50, 1.0)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.gray.opacity(0.2),
                                        Color.gray.opacity(0.4)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: geometry.size.width * 0.6, height: geometry.size.height * 0.025)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.yellow,
                                        Color.yellow.opacity(0.8)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: geometry.size.width * 0.6 * progress, height: geometry.size.height * 0.025)
                            .overlay(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.4),
                                                Color.clear
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                            .shadow(color: Color.yellow.opacity(0.3), radius: 2, x: 0, y: 0)
                    }
                    .frame(width: geometry.size.width * 0.6, height: geometry.size.height * 0.025)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.97)
                    .zIndex(50)

                    // Betting UI (shown only during betting phase)
                    if game.state.phase == .betting {
                        BlackjackBettingView(
                            game: game,
                            isPlaceBetDisabled: $isPlaceBetDisabled
                        )
                        .frame(maxWidth: .infinity)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.715)
                        .offset(y: bettingUIOffset)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                bettingUIOffset = 0
                            }
                        }
                    }
                    // Player turn action buttons (Hit, Stand, Double, Split)
                    if game.state.phase == .playerTurn && showPlayerTurnButtons {
                        BlackjackPlayerTurnButtonsView(game: game, onDouble: {
                            showPlayerTurnButtons = false
                        })
                        .frame(width: 320, height: 50)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.82)
                        .zIndex(100)  // Ensure it's above other elements
                    }
                    // Resolution UI (Change Bet / Repeat Bet buttons)
                    if game.state.phase == .resolution && showResolutionButtons && game.state.playerBalance > 0 {
                        HStack(spacing: 8) {
                            // Always show Change Bet
                            Button(action: {
                                isChangeBetDisabled = true
                                game.changeBet()
                            }) {
                                Text("Change Bet")
                                    .font(.system(size: 24, weight: .heavy))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 1, x: 0, y: 0)
                                    .frame(width: 150, height: 50)
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
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .disabled(isChangeBetDisabled)
                            .buttonStyle(ScaleButtonStyle())

                            // Only show Repeat Bet if player has enough balance
                            if game.state.initialBet > 0 && game.state.initialBet <= game.state.playerBalance {
                                Button(action: {
                                    isRepeatBetDisabled = true
                                    game.repeatBet()
                                }) {
                                    Text("Repeat Bet")
                                        .font(.system(size: 24, weight: .heavy))
                                        .foregroundColor(.white)
                                        .shadow(color: .black, radius: 1, x: 0, y: 0)
                                        .frame(width: 150, height: 50)
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
                                        .cornerRadius(8)
                                        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .disabled(isRepeatBetDisabled)
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .frame(width: 320, height: 50)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.84)
                        .zIndex(100)  // Ensure it's above other elements
                    }

                    // Reset Bankroll button (only shown when balance is 0 and after a hand)
                    if game.state.phase == .resolution && game.state.playerBalance == 0 {
                        Button(action: {
                            game.resetBankroll()
                            // Clear states after animation completes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                flippedCards.removeAll()
                                handNotificationOpacities.removeAll()
                                pendingNotifications.removeAll()
                                flippedCardCounts.removeAll()
                                showResolutionButtons = false
                            }
                        }) {
                            Text("Reset Bankroll")
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 1, x: 0, y: 0)
                                .frame(width: 200, height: 50)
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
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.84)
                        .zIndex(100)
                    }

                    // Hand and bonus notifications
                    BlackjackNotificationView(
                        playerHands: game.state.playerHands,
                        handNotifications: pendingNotifications,
                        handNotificationOpacities: $handNotificationOpacities,
                        flippedCardCounts: flippedCardCounts,
                        showResolutionButtons: $showResolutionButtons,
                        game: game,
                        geometry: geometry
                    )
                    .zIndex(200)

                    // Insurance notification
                    if !game.state.notification.isEmpty {
                        VStack {
                            Spacer()
                            let splitText = game.state.notification.split(separator: "\n")
                            VStack(spacing: 8) {
                                Text(String(splitText[0]))
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.white)
                                
                                if splitText.count > 1 {
                                    let amount = String(splitText[1])
                                        .replacingOccurrences(of: "$", with: "")
                                        .replacingOccurrences(of: "+", with: "")
                                        .replacingOccurrences(of: "-", with: "")
                                    Text(amount)
                                        .font(.system(size: 42, weight: .bold))
                                        .foregroundColor(splitText[1].contains("+") ? .green : .red)
                                }
                            }
                            .padding(16)
                            .background(
                                Color.black
                                    .opacity(0.5)
                                    .blur(radius: 25)
                            )
                            .shadow(color: .black.opacity(0.95), radius: 15, x: 0, y: 8)
                            .opacity(insuranceNotificationOpacity)
                            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.5)
                            Spacer()
                        }
                        .zIndex(200)
                    }

                    // Insurance result notification
                    if let insuranceText = game.insuranceResultNotification {
                        let splitText: (String, String) = {
                            if let range = insuranceText.range(of: "\n") {
                                let firstPart = String(insuranceText[..<range.lowerBound])
                                let secondPart = String(insuranceText[range.upperBound...])
                                return (firstPart, secondPart)
                            }
                            return (insuranceText, "")
                        }()
                        let isPositive = insuranceText.contains("+$")
                        let isNegative = insuranceText.contains("-$")
                        VStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Text(splitText.0)
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.white)
                                if !splitText.1.isEmpty {
                                    let amount = splitText.1
                                        .replacingOccurrences(of: "$", with: "")
                                        .replacingOccurrences(of: "+", with: "")
                                        .replacingOccurrences(of: "-", with: "")
                                    Text(amount)
                                        .font(.system(size: 42, weight: .bold))
                                        .foregroundColor(isPositive ? .green : isNegative ? .red : .white)
                                }
                            }
                            .padding(16)
                            .background(
                                Color.black
                                    .opacity(0.5)
                                    .blur(radius: 25)
                            )
                            .shadow(color: .black.opacity(0.95), radius: 15, x: 0, y: 8)
                            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.5)
                            Spacer()
                        }
                        .zIndex(200)
                        .transition(.opacity)
                        .animation(.easeInOut, value: insuranceText)
                    }
                }
            }

            // Reshuffle notification
            if game.isReshuffling {
                GeometryReader { geometry in
                    BlackjackShuffleView(game: game, geometry: geometry)
                        .transition(.opacity)
                }
            }

            // Fallback for resolution buttons
            if game.state.phase == .resolution && handNotificationOpacities.isEmpty && !showResolutionButtons {
                Text("")
                    .onAppear {
                        showResolutionButtons = true
                    }
            }

            // Insurance overlay
            insuranceOverlayView
        }
        .overlay(
            Button(action: { dismiss() }) {
                Image(systemName: "house.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .foregroundColor(.white)
                    .shadow(radius: 3)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, -10)
            .padding(.trailing, 100)
            .zIndex(100),
            alignment: .topTrailing
        )
        .onAppear {
            // Add all dealt cards to flippedCards so they appear face up without animation
            var allCardIDs: Set<UUID> = []
            for hand in game.state.playerHands {
                for card in hand {
                    allCardIDs.insert(card.id)
                }
            }
            // Only add dealer's first card and second card if it's revealed
            if let firstCard = game.state.dealerHand.first {
                allCardIDs.insert(firstCard.id)
            }
            if game.dealerHoleCardRevealed, let secondCard = game.state.dealerHand.dropFirst().first {
                allCardIDs.insert(secondCard.id)
            }
            flippedCards = allCardIDs
            
            // Set showPlayerTurnButtons based on current phase when view appears
            showPlayerTurnButtons = game.state.phase == .playerTurn

            // Reset isInitialAppearance after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInitialAppearance = false
            }
        }
        .onChange(of: game.state.handNotifications) { oldNotifications, newNotifications in
            pendingNotifications.removeAll()
            for (index, notification) in newNotifications.enumerated() {
                if !notification.isEmpty {
                    pendingNotifications[index] = notification
                    flippedCardCounts[index] = flippedCardCounts[index] ?? 0
                }
            }
        }
        .onChange(of: game.state.phase) { oldPhase, newPhase in
            // Only show buttons when transitioning to playerTurn AND not during split hand dealing
            showPlayerTurnButtons = newPhase == .playerTurn && game.state.playerHands[game.state.activeHandIndex].count >= 2
            
            if newPhase == .dealing && oldPhase == .betting {
                // Only clear flippedCards when starting a new round from betting phase
                flippedCards.removeAll()
                flippedCardCounts.removeAll()
                isInitialAppearance = false  // Reset flag when dealing starts
            }
            
            if newPhase == .betting {
                isPlaceBetDisabled = false
                showResolutionButtons = false
                bettingUIOffset = 500
            } else {
                bettingUIOffset = 500
            }
            
            if newPhase == .resolution {
                // Reset button states when entering resolution phase
                isRepeatBetDisabled = false
                isChangeBetDisabled = false
            }
            
            if newPhase == .clearTable {
                // Hide hand totals and trigger card sliding animation
                showHandTotals = false
                withAnimation(.easeInOut(duration: 0.8)) {
                    isSlidingOut = true
                }
            }
            
            if newPhase == .shuffleDecks {
                // Hide hand totals during shuffle
                showHandTotals = false
            }
            
            if newPhase == .dealing {
                // Show hand totals again when starting to deal new cards
                showHandTotals = true
                isSlidingOut = false
            }
        }
        .onChange(of: game.state.activeHandIndex) { oldIndex, newIndex in
            // Only show buttons if the current hand has at least 2 cards
            showPlayerTurnButtons = game.state.phase == .playerTurn && game.state.playerHands[newIndex].count >= 2
            // Don't clear flippedCards here, let the CardView handle it
        }
        .alert(isPresented: $showingQuitAlert) {
            Alert(
                title: Text("Quit Game"),
                message: Text("Are you sure you want to quit? Your balance will be saved."),
                primaryButton: .destructive(Text("Quit")) {
                    game.quitGame()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showInfoView) {
            InfoView()
        }
    }

    // Extracted Insurance Overlay View
    private var insuranceOverlayView: some View {
        Group {
            if game.state.insuranceOffered && !game.state.insuranceAccepted {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 10) {
                        Text("Insurance? (Up to $\(game.state.currentBet / 2))")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                        
                        HStack(spacing: 20) {
                            Button(action: {
                                game.acceptInsurance(amount: game.state.currentBet / 2)
                            }) {
                                Text("Accept")
                                    .font(.system(size: 24, weight: .heavy))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 1, x: 0, y: 0)
                                    .frame(width: 128, height: 50)
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
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            Button(action: {
                                game.declineInsurance()
                            }) {
                                Text("Decline")
                                    .font(.system(size: 24, weight: .heavy))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 1, x: 0, y: 0)
                                    .frame(width: 128, height: 50)
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
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .transition(.opacity)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.3))
            }
        }
    }

    private var dealingView: some View {
        BlackjackDealingView(
            game: game,
            flippedCards: $flippedCards,
            flippedCardCounts: $flippedCardCounts,
            isSlidingOut: isSlidingOut,
            isInitialAppearance: isInitialAppearance,
            showHandTotals: showHandTotals
        )
    }
}

struct BlackjackView_Previews: PreviewProvider {
    static var previews: some View {
        BlackjackView(game: BlackjackGame())
    }
}
