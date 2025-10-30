import SwiftUI

struct PracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @StateObject private var practiceGame: PracticeGame
    @State private var flippedCards: Set<UUID> = []
    @StateObject private var dummyGame = BlackjackGame() // For CardView animations
    @State private var showPlayerTurnButtons = true
    @State private var showActionButtons = false
    @State private var isSlidingOut = false
    @State private var showFeedback = false // New state to control feedback visibility
    @State private var isDealButtonEnabled = true // New state for immediate button locking
    @State private var showHandTotals = true
    @State private var showInfoView = false  // Add this state variable
    
    init(blackjackGame: BlackjackGame) {
        _practiceGame = StateObject(wrappedValue: PracticeGame(blackjackGame: blackjackGame))
    }
    
    private func getScreenType(for geometry: GeometryProxy) -> ScreenType {
        if horizontalSizeClass == .compact {
            return .phone
        } else if geometry.size.width < 900 {
            return .miniTablet
        } else {
            return .tablet
        }
    }
    
    private func getCardsYPosition(for screenType: ScreenType) -> CGFloat {
        switch screenType {
        case .phone: return 0.42
        case .miniTablet: return 0.47
        case .tablet: return 0.50
        }
    }
    
    private func getButtonsYPosition(for screenType: ScreenType) -> CGFloat {
        switch screenType {
        case .phone: return 0.78
        case .miniTablet: return 0.72
        case .tablet: return 0.68
        }
    }
    
    private func getProgressBarYPosition(for screenType: ScreenType) -> CGFloat {
        switch screenType {
        case .phone: return 0.94
        case .miniTablet: return 0.90
        case .tablet: return 0.88
        }
    }
    
    private func getProgressCountYPosition(for screenType: ScreenType) -> CGFloat {
        switch screenType {
        case .phone: return 0.90
        case .miniTablet: return 0.86
        case .tablet: return 0.84
        }
    }
    
    private func getPracticeLabelYPosition(for screenType: ScreenType) -> CGFloat {
        switch screenType {
        case .phone: return 0.05
        case .miniTablet: return 0.12
        case .tablet: return 0.15
        }
    }
    
    private func getIconPadding() -> CGFloat {
        switch horizontalSizeClass {
        case .compact: return -10
        case .regular: return 150
        default: return -10
        }
    }
    
    private func getButtonWidth(for screenType: ScreenType, geometry: GeometryProxy) -> CGFloat {
        switch screenType {
        case .phone: return min(400, geometry.size.width * 0.95)
        case .miniTablet: return min(450, geometry.size.width * 0.85)
        case .tablet: return min(500, geometry.size.width * 0.8)
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Image("IMG_3879")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            // Info and Home Icons (in same container for consistent positioning)
            GeometryReader { geometry in
                HStack {
                    // Info Button (left side)
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
                    .padding(.leading, 100)
                    
                    Spacer()
                    
                    // Home Button (right side)
                    Button(action: { dismiss() }) {
                        Image(systemName: "house.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .foregroundColor(.white)
                            .shadow(radius: 3)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.trailing, 100)
                }
                .padding(.top, getIconPadding())
                .zIndex(100)  // Ensure both are above other elements
            }

            GeometryReader { geometry in
                ZStack {
                    let screenType = getScreenType(for: geometry)
                    
                    // Main Content (cards, actions)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        dealingView
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: geometry.size.height * 0.55)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * getCardsYPosition(for: screenType))
                    .zIndex(0)

                    // Practice Mode Label
                    Text("Practice Mode")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .zIndex(100)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * getPracticeLabelYPosition(for: screenType))

                    // Progress Bar
                    PracticeProgressBar(progress: Double(practiceGame.consecutiveCorrect) / 25.0, barWidth: 300)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .zIndex(50)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * getProgressBarYPosition(for: screenType))

                    // Progress Count
                    Text("\(practiceGame.consecutiveCorrect)/25")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2, x: 0, y: 1)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .zIndex(150)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * getProgressCountYPosition(for: screenType))

                    // Feedback notification overlay
                    if showFeedback && !practiceGame.feedbackMessage.isEmpty {
                        VStack(spacing: 8) {
                            if practiceGame.feedbackMessage.contains("\n") {
                                let components = practiceGame.feedbackMessage.components(separatedBy: "\n")
                                Text(components[0])
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.green)
                                    .multilineTextAlignment(.center)
                                Text(components[1])
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text(practiceGame.feedbackMessage)
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(practiceGame.isCorrect ? .green : .red)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(16)
                        .background(
                            Color.black
                                .opacity(0.5)
                                .blur(radius: 25)
                        )
                        .shadow(color: .black.opacity(0.95), radius: 15, x: 0, y: 8)
                        .frame(maxWidth: .infinity)
                        .zIndex(200)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .transition(.opacity)
                        .animation(.easeInOut, value: showFeedback)
                    }

                    // Deal button overlay
                    if !practiceGame.isDealing && 
                       practiceGame.state.phase != .clearPracticeTable && 
                       ((practiceGame.state.phase == .practiceDealing && practiceGame.canShowDealButton) || 
                        (practiceGame.state.phase == .practiceFeedback && practiceGame.canShowDealButton && !showFeedback)) {
                        Button(action: {
                            practiceGame.handleDealButton()
                        }) {
                            Text("Deal")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 60)
                                .padding(.vertical, 10)
                                .background(Color.gold)
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .zIndex(200)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * getButtonsYPosition(for: screenType))
                    }

                    // Action buttons overlay
                    if practiceGame.state.phase == .practicePlayerChoice || (practiceGame.state.phase == .practiceFeedback && practiceGame.shouldShowActionButtons) {
                        HStack(spacing: 8) {
                            // Only show Split if both player cards are the same rank
                            if practiceGame.state.playerHands[0].count == 2 && practiceGame.state.playerHands[0][0].rank == practiceGame.state.playerHands[0][1].rank {
                                PracticeActionButton(
                                    title: "Split",
                                    color: .richRed,
                                    action: { practiceGame.makeChoice(.split) },
                                    isFlashing: practiceGame.correctActionToFlash == .split
                                )
                            }
                            // Only show Double if hand has exactly two cards
                            if practiceGame.state.playerHands[0].count == 2 {
                                PracticeActionButton(
                                    title: "Double",
                                    color: .silver,
                                    action: { practiceGame.makeChoice(.double) },
                                    isFlashing: practiceGame.correctActionToFlash == .double
                                )
                            }
                            // Always show Stand and Hit
                            PracticeActionButton(
                                title: "Stand",
                                color: .gold,
                                action: { practiceGame.makeChoice(.stand) },
                                isFlashing: practiceGame.correctActionToFlash == .stand
                            )
                            PracticeActionButton(
                                title: "Hit",
                                color: .richBlack,
                                action: { practiceGame.makeChoice(.hit) },
                                isFlashing: practiceGame.correctActionToFlash == .hit
                            )
                        }
                        .frame(width: getButtonWidth(for: screenType, geometry: geometry))
                        .zIndex(100)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * getButtonsYPosition(for: screenType))
                    }
                }
            }
            .onAppear {
                practiceGame.onDealNewHand = {
                    // Do not clear flippedCards here; only clear when starting a new deal
                }
                practiceGame.onSlideOut = {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        isSlidingOut = true
                    }
                    // Reset isSlidingOut and clear flippedCards after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        isSlidingOut = false
                        flippedCards.removeAll() // Clear flippedCards after slide-out animation
                    }
                }
                showActionButtons = false
            }
            .onChange(of: practiceGame.state.phase) { oldPhase, newPhase in
                print("Phase changed from \(oldPhase) to \(newPhase)")
                if newPhase == .practicePlayerChoice {
                    showActionButtons = true
                } else {
                    showActionButtons = false
                }
            }
            .onChange(of: practiceGame.feedbackMessage) { _, newMessage in
                print("Feedback message changed to: \(newMessage)")
                if !newMessage.isEmpty {
                    showFeedback = true
                    // Hide feedback after 1.6 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation {
                            showFeedback = false
                        }
                        if !practiceGame.isCorrect {
                            showActionButtons = false
                        }
                    }
                } else {
                    showFeedback = false
                }
                if newMessage.isEmpty {
                    showActionButtons = false
                }
            }
        }
        .sheet(isPresented: $showInfoView) {
            PracticeInfoView()
        }
    }

    private var dealingView: some View {
        VStack(spacing: 40) {
            // Dealer's hand
            VStack(spacing: 8) {
                let visibleDealerCards = practiceGame.state.dealerHand.enumerated().filter { index, card in
                    if index == 1 && !practiceGame.revealDealerHoleCard { return false } // Hide hole card unless revealed
                    return flippedCards.contains(card.id) || (index == 1 && practiceGame.revealDealerHoleCard)
                }.map { $0.1 }
                let dealerValue = visibleDealerCards.isEmpty ? nil : practiceGame.calculateHandValue(visibleDealerCards)
                if let value = dealerValue, practiceGame.state.phase != .clearPracticeTable {
                    Text("\(value)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .frame(height: 30)
                } else {
                    Spacer().frame(height: 30)
                }
                ZStack {
                    ForEach(practiceGame.state.dealerHand.indices, id: \.self) { index in
                        let card = practiceGame.state.dealerHand[index]
                        let isTopmost = index == practiceGame.state.dealerHand.count - 1
                        let isHoleCard = index == 1
                        CardView(
                            card: card,
                            isFaceDown: isHoleCard && !practiceGame.revealDealerHoleCard,
                            isTopmostFaceUp: isTopmost && (!isHoleCard || practiceGame.revealDealerHoleCard),
                            shouldAnimateFlip: (!isHoleCard || practiceGame.revealDealerHoleCard) && practiceGame.cardToFlip == card.id,
                            flippedCards: $flippedCards,
                            game: dummyGame,
                            shouldSlideOut: isSlidingOut,
                            onFlipComplete: {
                                if practiceGame.cardToFlip == card.id {
                                    flippedCards.insert(card.id)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        practiceGame.dealNextStep()
                                    }
                                }
                            }
                        )
                        .offset(x: CGFloat(index * 25), y: isHoleCard ? 0 : 0)
                        .animation(.easeInOut(duration: 0.3), value: practiceGame.revealDealerHoleCard)
                    }
                }
                .frame(width: 170, height: 180)
            }
            .frame(height: 218)

            // Player's hand
            VStack(spacing: 8) {
                let visibleCards = practiceGame.state.playerHands[0].filter { flippedCards.contains($0.id) }
                let handValue = visibleCards.isEmpty ? nil : practiceGame.calculateHandValue(visibleCards)
                if let value = handValue, practiceGame.state.phase != .clearPracticeTable {
                    Text("\(value)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .frame(height: 30)
                } else {
                    Spacer().frame(height: 30)
                }
                ZStack {
                    ForEach(practiceGame.state.playerHands[0].indices, id: \.self) { index in
                        let card = practiceGame.state.playerHands[0][index]
                        let isTopmost = index == practiceGame.state.playerHands[0].count - 1
                        CardView(
                            card: card,
                            isFaceDown: false,
                            isTopmostFaceUp: isTopmost,
                            shouldAnimateFlip: practiceGame.cardToFlip == card.id,
                            flippedCards: $flippedCards,
                            game: dummyGame,
                            shouldSlideOut: isSlidingOut,
                            onFlipComplete: {
                                if practiceGame.cardToFlip == card.id {
                                    flippedCards.insert(card.id)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        practiceGame.dealNextStep()
                                    }
                                }
                            }
                        )
                        .offset(x: CGFloat(index * 25), y: 0)
                    }
                }
                .frame(width: 170, height: 180)
            }
            .frame(height: 218)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 0)
    }
}

struct PracticeProgressBar: View {
    let progress: Double // 0.0 to 1.0
    var barWidth: CGFloat = 200
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: barWidth, height: 18)
            Capsule()
                .fill(Color.yellow)
                .frame(width: CGFloat(barWidth * progress), height: 18)
        }
        .frame(width: barWidth, height: 18)
        .overlay(
            Capsule()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: barWidth, height: 18)
        )
    }
}

struct PracticeActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    var isFlashing: Bool = false
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.white)
                .shadow(color: .black, radius: 1, x: 0, y: 0)
                .frame(width: 90, height: 50)
                .background(
                    ZStack {
                        color
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
                        .stroke(isFlashing ? Color.red : Color.white.opacity(0.3), lineWidth: isFlashing ? 6 : 1)
                        .animation(isFlashing ? .easeInOut(duration: 0.2).repeatCount(4, autoreverses: true) : .default, value: isFlashing)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct PracticeView_Previews: PreviewProvider {
    static var previews: some View {
        PracticeView(blackjackGame: BlackjackGame())
    }
}
