import SwiftUI

struct ColoredNotification {
    let text: String
    let amount: Int
    let isPositive: Bool
    let isPush: Bool
    
    var formattedMessage: String {
        if isPush {
            return text
        } else if isPositive {
            return "\(text)\n\(amount)"
        } else {
            return "\(text)\n\(amount)"
        }
    }
}

class BlackjackGame: ObservableObject {
    @Published private(set) var state: GameState
    @Published private(set) var deck: Deck
    @Published private(set) var rules: GameRules
    @Published var dealerHoleCardRevealed: Bool = false
    @Published var isDealerCheckingHoleCard: Bool = false
    @Published var insuranceResultNotification: String? = nil
    @Published var bonusNotification: String? = nil
    @Published var isReshuffling: Bool = false
    @Published var isChangingBet: Bool = false // Exposed for view
    private let persistence: GamePersistence
    private var analytics: [String: Any] = ["games_started": 0, "total_bets": 0, "average_bet": 0.0, "player_blackjacks": 0, "dealer_blackjacks": 0, "pushes": 0, "hits": 0, "stands": 0, "doubles": 0, "splits": 0]
    private var predefinedPlayerCards: [Card]?
    private var predefinedDealerCards: [Card]?
    private var isRoundActive: Bool = false // Track if a round is active
    private var lastActionTime: Date? = nil // Track last action time for debouncing
    
    init(persistence: GamePersistence = GamePersistence()) {
        self.state = GameState()
        self.rules = GameRules()
        self.deck = try! Deck(numDecks: 4)
        self.persistence = persistence
        setup()
    }
    
    private func setup() {
        do {
            try rules.validate()
        } catch {
            print("Rule validation failed: \(error). Using default rules.")
            rules = GameRules()
        }
        
        do {
            deck = try Deck(numDecks: rules.numDecks)
        } catch {
            print("Deck initialization failed: \(error). Using single deck.")
            deck = try! Deck(numDecks: 1)
        }
        
        state = persistence.loadState() ?? GameState()
        if state.playerBalance <= 0 {
            state.playerBalance = 10000
        }
        
        setPhase(.betting)
        
        analytics["games_started"] = (analytics["games_started"] as? Int ?? 0) + 1
        
        persistence.saveState(state)
    }
    
    func setPredefinedCards(playerCards: [Card]?, dealerCards: [Card]?) {
        guard playerCards == nil || playerCards!.count == 2 else {
            print("Invalid player cards: Must be exactly 2 cards or nil")
            return
        }
        guard dealerCards == nil || dealerCards!.count == 2 else {
            print("Invalid dealer cards: Must be exactly 2 cards or nil")
            return
        }
        predefinedPlayerCards = playerCards
        predefinedDealerCards = dealerCards
    }
    
    // MARK: - Betting Phase Methods
    
    func addToBet(amount: Int) {
        let newBet = state.currentBet + amount
        if newBet <= state.playerBalance && newBet > 0 {
            state.currentBet = newBet
            persistence.saveState(state)
        }
    }
    
    func clearBet() {
        state.currentBet = 0
        persistence.saveState(state)
    }
    
    var isBetValid: Bool {
        return state.currentBet > 0 && state.currentBet <= state.playerBalance
    }
    
    var betValidationMessage: String {
        if state.currentBet == 0 {
            return "Please place a bet."
        } else if state.currentBet > state.playerBalance {
            return "Insufficient funds. Max bet: \(state.playerBalance)."
        }
        return ""
    }
    
    func confirmBet() {
        guard state.phase == .betting else {
            return
        }
        guard isBetValid else {
            return
        }
        
        state.playerBalance -= state.currentBet
        state.initialBet = state.currentBet
        state.bets = [state.currentBet]
        
        let totalBets = (analytics["total_bets"] as? Int ?? 0) + 1
        let totalBetAmount = (analytics["average_bet"] as? Double ?? 0) * Double(totalBets - 1) + Double(state.currentBet)
        analytics["total_bets"] = totalBets
        analytics["average_bet"] = totalBetAmount / Double(totalBets)
        
        setPhase(.dealing)
        dealCards()
    }
    
    func repeatBet() {
        if let lastTime = lastActionTime, Date().timeIntervalSince(lastTime) < 1.0 {
            return
        }
        lastActionTime = Date()
        
        guard state.phase == .resolution else {
            return
        }
        
        // Only allow repeat bet if player has enough balance
        if state.currentBet > state.playerBalance {
            return
        }
        
        // Deduct the bet from the balance for repeat bet immediately
        state.playerBalance -= state.currentBet
        
        // Transition to clearTable phase first
        setPhase(.clearTable)
        
        // The state will be cleared in handleClearTablePhase after the animation completes
        persistence.saveState(state)
    }
    
    func changeBet() {
        if let lastTime = lastActionTime, Date().timeIntervalSince(lastTime) < 1.0 {
            return
        }
        lastActionTime = Date()
        
        guard state.phase == .resolution else {
            return
        }
        
        // Set flag before transitioning to clearTable
        isChangingBet = true
        
        // Transition to clearTable phase first
        setPhase(.clearTable)
        
        // The state will be cleared in handleClearTablePhase after the animation completes
        persistence.saveState(state)
    }
    
    func quitGame() {
        persistence.saveState(state)
        state = GameState()
        setup()
    }
    
    func allIn() {
        state.currentBet = state.playerBalance
        persistence.saveState(state)
    }
    
    // MARK: - Dealing Phase Methods
    
    private func reshuffleDeck() {
        // First transition to shuffle phase
        setPhase(.shuffleDecks)
        
        // Then show the shuffle view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isReshuffling = true
            self.state.notification = "Reshuffling Deck..."
            self.persistence.saveState(self.state)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                do {
                    self.deck = try Deck(numDecks: self.rules.numDecks)
                } catch {
                    print("Deck reshuffle failed: \(error)")
                    self.deck = try! Deck(numDecks: 1)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.state.notification = ""
                    self.isReshuffling = false
                    self.persistence.saveState(self.state)
                    
                    // After reshuffling is complete, transition to the appropriate phase
                    if self.state.phase == .shuffleDecks {
                        self.setPhase(.dealing)
                        self._dealInitialCards()
                    }
                }
            }
        }
    }

    // Add new function to handle shuffle phase transition
    private func handleShufflePhase() {
        // Show the shuffle view immediately
        self.isReshuffling = true
        self.state.notification = "Reshuffling Deck..."
        self.persistence.saveState(self.state)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            do {
                self.deck = try Deck(numDecks: self.rules.numDecks)
            } catch {
                print("Deck reshuffle failed: \(error)")
                self.deck = try! Deck(numDecks: 1)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.state.notification = ""
                self.isReshuffling = false
                self.persistence.saveState(self.state)
                
                // After reshuffling is complete, transition to the appropriate phase
                if self.state.phase == .shuffleDecks {
                    if self.isChangingBet {
                        self.isChangingBet = false
                        self.setPhase(.betting)
                    } else {
                        self.setPhase(.dealing)
                        self._dealInitialCards()
                    }
                }
            }
        }
    }
    
    func dealCards() {
        _dealInitialCards()
    }
    
    private func _dealInitialCards() {
        state.playerHands = [[]]
        state.dealerHand = []
        state.activeHandIndex = 0
        state.bets = [state.currentBet]
        state.splitCount = 0
        state.notification = ""
        state.handNotifications = []
        state.insuranceBet = 0
        state.insuranceOffered = false
        state.insuranceAccepted = false
        dealerHoleCardRevealed = false
        persistence.saveState(state)
        
        let animationDuration = 0.6
        var currentDelay: Double = 0.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) {
            guard let card = self.deck.draw() else {
                print("Error: Deck empty during player draw 1")
                self.state.resolutionMessage = "Error: Deck empty. Game reset."
                self.state.notification = ""
                self.state.handNotifications = []
                self.setPhase(.resolution)
                return
            }
            self.state.playerHands[0].append(card)
            self.persistence.saveState(self.state)
        }
        currentDelay += animationDuration
        
        DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) {
            guard let card = self.deck.draw() else {
                print("Error: Deck empty during dealer draw 1")
                self.state.resolutionMessage = "Error: Deck empty. Game reset."
                self.state.notification = ""
                self.state.handNotifications = []
                self.setPhase(.resolution)
                return
            }
            self.state.dealerHand.append(card)
            self.persistence.saveState(self.state)
        }
        currentDelay += animationDuration
        
        DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) {
            guard let card = self.deck.draw() else {
                print("Error: Deck empty during player draw 2")
                self.state.resolutionMessage = "Error: Deck empty. Game reset."
                self.state.notification = ""
                self.state.handNotifications = []
                self.setPhase(.resolution)
                return
            }
            self.state.playerHands[0].append(card)
            self.persistence.saveState(self.state)
        }
        currentDelay += animationDuration
        
        DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) {
            guard let card = self.deck.draw() else {
                print("Error: Deck empty during dealer draw 2")
                self.state.resolutionMessage = "Error: Deck empty. Game reset."
                self.state.notification = ""
                self.state.handNotifications = []
                self.setPhase(.resolution)
                return
            }
            self.state.dealerHand.append(card)
            self.persistence.saveState(self.state)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if self.state.dealerHand[0].rank == .ace {
                    self.state.insuranceOffered = true
                    self.state.notification = "Insurance? (Up to \(self.state.currentBet / 2))"
                    self.persistence.saveState(self.state)
                } else {
                    self.checkForBlackjack()
                }
            }
        }
    }
    
    // MARK: - Player's Turn Phase Methods
    
    func hit() {
        if let lastTime = lastActionTime, Date().timeIntervalSince(lastTime) < 1.0 {
            return
        }
        lastActionTime = Date()
        
        guard state.phase == .playerTurn else {
            return
        }
        
        if state.activeHandIndex >= state.playerHands.count && !state.playerHands.isEmpty {
            state.activeHandIndex = 0
        }
        guard state.activeHandIndex < state.playerHands.count else {
            return
        }
        guard !state.playerHands[state.activeHandIndex].isEmpty else {
            return
        }
        
        let handValue = calculateHandValue(state.playerHands[state.activeHandIndex])
        guard handValue < 21 else {
            return
        }
        
        guard deck.cardsRemaining > 0, let card = deck.draw() else {
            print("Error: Deck empty during hit for hand \(state.activeHandIndex + 1), cards remaining: \(deck.cardsRemaining)")
            state.resolutionMessage = "Error: Deck empty. Game reset."
            state.notification = ""
            state.handNotifications = []
            setPhase(.resolution)
            return
        }
        
        state.playerHands[state.activeHandIndex].append(card)
        let newHandValue = calculateHandValue(state.playerHands[state.activeHandIndex])
        
        analytics["hits"] = (analytics["hits"] as? Int ?? 0) + 1
        persistence.saveState(state)
        
        if isHandBusted(state.playerHands[state.activeHandIndex]) {
            if state.handNotifications.count != state.playerHands.count {
                state.handNotifications = Array(repeating: "", count: state.playerHands.count)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.state.handNotifications[self.state.activeHandIndex] = "Bust\n-$\(self.state.bets[self.state.activeHandIndex])"
                self.persistence.saveState(self.state)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.advanceToNextHandOrResolve()
                }
            }
            return
        }
        
        if newHandValue == 21 {
            let hand = state.playerHands[state.activeHandIndex]
            let isInitialDeal = hand.count == 2 && state.playerHands.count == 1 && state.activeHandIndex == 0
            if !(hand.count == 2 && isInitialDeal) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.advanceToNextHandOrResolve()
                }
                return
            }
        }
        
        // Don't change phase, stay in playerTurn
    }
    
    func stand() {
        if let lastTime = lastActionTime, Date().timeIntervalSince(lastTime) < 1.0 {
            return
        }
        lastActionTime = Date()
        
        guard state.phase == .playerTurn else {
            return
        }
        
        guard state.activeHandIndex < state.playerHands.count else {
            return
        }
        
        analytics["stands"] = (analytics["stands"] as? Int ?? 0) + 1
        persistence.saveState(state)
        
        setPhase(.playerTurn)
        advanceToNextHandOrResolve()
    }
    
    func doubleDown() {
        if let lastTime = lastActionTime, Date().timeIntervalSince(lastTime) < 1.0 {
            return
        }
        lastActionTime = Date()
        
        guard state.phase == .playerTurn else {
            return
        }
        
        guard state.activeHandIndex < state.playerHands.count else {
            return
        }
        
        guard state.playerHands[state.activeHandIndex].count == 2 else {
            return
        }
        
        guard state.playerBalance >= state.bets[state.activeHandIndex] else {
            return
        }
        guard let card = deck.draw() else {
            print("Error: Failed to draw card for double down, cards remaining: \(deck.cardsRemaining)")
            state.resolutionMessage = "Error: Card draw failed. Game reset."
            state.notification = ""
            state.handNotifications = []
            setPhase(.resolution)
            return
        }
        
        state.playerBalance -= state.bets[state.activeHandIndex]
        state.bets[state.activeHandIndex] *= 2
        state.playerHands[state.activeHandIndex].append(card)
        
        let newHandValue = calculateHandValue(state.playerHands[state.activeHandIndex])
        
        analytics["doubles"] = (analytics["doubles"] as? Int ?? 0) + 1
        persistence.saveState(state)
        
        if isHandBusted(state.playerHands[state.activeHandIndex]) {
            if state.handNotifications.count != state.playerHands.count {
                state.handNotifications = Array(repeating: "", count: state.playerHands.count)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.state.handNotifications[self.state.activeHandIndex] = "Bust\n-$\(self.state.bets[self.state.activeHandIndex])"
                self.persistence.saveState(self.state)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.advanceToNextHandOrResolve()
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.advanceToNextHandOrResolve()
            }
        }
    }
    
    func split() {
        guard canSplit() else {
            return
        }
        
        let currentHand = state.playerHands[state.activeHandIndex]
        let secondCard = currentHand[1]
        
        state.playerHands[state.activeHandIndex] = [currentHand[0]]
        state.playerHands.append([secondCard])
        
        state.playerBalance -= state.bets[state.activeHandIndex]
        state.bets.append(state.bets[state.activeHandIndex])
        state.splitCount += 1
        
        let isSplittingAces = currentHand[0].rank == .ace
        
        analytics["splits"] = (analytics["splits"] as? Int ?? 0) + 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard let card = self.deck.draw() else {
                print("Error: Deck empty during split draw for hand 0, cards remaining: \(self.deck.cardsRemaining)")
                self.state.resolutionMessage = "Error: Deck empty. Game reset."
                self.state.notification = ""
                self.state.handNotifications = []
                self.setPhase(.resolution)
                return
            }
            self.state.playerHands[0].append(card)
            self.persistence.saveState(self.state)
            
            // If splitting aces, automatically stand on both hands
            if isSplittingAces {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    guard let secondCard = self.deck.draw() else {
                        print("Error: Deck empty during split draw for hand 1")
                        self.state.resolutionMessage = "Error: Deck empty. Game reset."
                        self.state.notification = ""
                        self.state.handNotifications = []
                        self.setPhase(.resolution)
                        return
                    }
                    self.state.playerHands[1].append(secondCard)
                    self.persistence.saveState(self.state)
                    
                    // Move to dealer turn after both aces are dealt
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.setPhase(.dealerTurn)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.playDealerTurn()
                        }
                    }
                }
            } else {
                self.setPhase(.playerTurn)
                let newHandValue = self.calculateHandValue(self.state.playerHands[self.state.activeHandIndex])
                let hand = self.state.playerHands[self.state.activeHandIndex]
                // Auto-advance if hand reaches 21 and is NOT a true blackjack (not 2 cards on initial deal)
                let isInitialDeal = hand.count == 2 && self.state.playerHands.count == 1 && self.state.activeHandIndex == 0
                if newHandValue == 21 && !(hand.count == 2 && isInitialDeal) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.advanceToNextHandOrResolve()
                    }
                }
            }
        }
    }
    
    private func advanceToNextHandOrResolve() {
        let allHandsBusted = state.playerHands.allSatisfy { isHandBusted($0) }
        if allHandsBusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.state.handNotifications = self.state.playerHands.enumerated().map { index, _ in
                    "Bust\n-$\(self.state.bets[index])"
                }
                self.persistence.saveState(self.state)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.dealerHoleCardRevealed = true
                    self.persistence.saveState(self.state)
                }
                self.setPhase(.resolution)
            }
            return
        }
        
        // Only change phase if we're moving to dealer turn or next hand
        if state.playerHands.count == 1 {
            setPhase(.dealerTurn)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.playDealerTurn()
            }
        } else if state.activeHandIndex < state.playerHands.count - 1 {
            state.activeHandIndex += 1
            persistence.saveState(state)
            if state.playerHands[state.activeHandIndex].count == 1 {
                // Keep in dealing phase while dealing the second card
                setPhase(.dealing)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    guard let card = self.deck.draw() else {
                        print("Error: Deck empty during second hand draw")
                        self.state.resolutionMessage = "Error: Deck empty. Game reset."
                        self.state.notification = ""
                        self.state.handNotifications = []
                        self.setPhase(.resolution)
                        return
                    }
                    self.state.playerHands[self.state.activeHandIndex].append(card)
                    self.persistence.saveState(self.state)
                    
                    // Only transition to playerTurn if the hand hasn't reached 21
                    let newHandValue = self.calculateHandValue(self.state.playerHands[self.state.activeHandIndex])
                    let hand = self.state.playerHands[self.state.activeHandIndex]
                    let isInitialDeal = hand.count == 2 && self.state.playerHands.count == 1 && self.state.activeHandIndex == 0
                    
                    if newHandValue == 21 && !(hand.count == 2 && isInitialDeal) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.advanceToNextHandOrResolve()
                        }
                    } else {
                        self.setPhase(.playerTurn)
                    }
                }
            }
        } else {
            setPhase(.dealerTurn)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.playDealerTurn()
            }
        }
    }
    
    private func playDealerTurn() {
        setPhase(.dealerTurn)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.dealerHoleCardRevealed = true
            self.persistence.saveState(self.state)
            
            let activeHands = self.state.playerHands.filter { !self.isHandBusted($0) }
            if activeHands.isEmpty {
                self.resolveRound()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.continueDealerTurn()
                }
            }
        }
    }
    
    private func continueDealerTurn() {
        let dealerValue = calculateHandValue(state.dealerHand)
        
        if dealerValue < 17 {
            guard let card = deck.draw() else {
                print("Error: Deck empty during dealer draw")
                state.resolutionMessage = "Error: Dealer deck empty. Game reset."
                state.notification = ""
                state.handNotifications = []
                setPhase(.resolution)
                return
            }
            
            state.dealerHand.append(card)
            persistence.saveState(state)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                self.continueDealerTurn()
            }
        } else {
            self.resolveRound()
        }
    }
    
    private func hasSoft17() -> Bool {
        let dealerValue = calculateHandValue(state.dealerHand)
        if dealerValue != 17 {
            return false
        }
        
        var aces = 0
        var otherCardsValue = 0
        
        for card in state.dealerHand {
            switch card.rank {
            case .ace:
                aces += 1
            case .two:
                otherCardsValue += 2
            case .three:
                otherCardsValue += 3
            case .four:
                otherCardsValue += 4
            case .five:
                otherCardsValue += 5
            case .six:
                otherCardsValue += 6
            case .seven:
                otherCardsValue += 7
            case .eight:
                otherCardsValue += 8
            case .nine:
                otherCardsValue += 9
            case .ten, .jack, .queen, .king:
                otherCardsValue += 10
            }
        }
        
        return aces > 0 && (otherCardsValue + aces - 1) == 6
    }
    
    private func resolveRound() {
        let dealerValue = calculateHandValue(state.dealerHand)
        var totalPayout = 0
        
        guard state.phase == .dealerTurn else {
            return
        }
        
        if state.handNotifications.count != state.playerHands.count {
            state.handNotifications = Array(repeating: "", count: state.playerHands.count)
        }
        
        for index in 0..<state.playerHands.count {
            if !state.handNotifications[index].isEmpty {
                continue
            }
            
            let playerValue = calculateHandValue(state.playerHands[index])
            let bet = state.bets[index]
            let outcome = calculatePayout(playerValue: playerValue, dealerValue: dealerValue, bet: bet)
            totalPayout += outcome.payout
            state.handNotifications[index] = outcome.notification.formattedMessage
        }
        
        state.playerBalance += totalPayout
        setPhase(.resolution)
        
        // Check for reshuffle after notifications are complete
        let totalCards = rules.numDecks * 52
        let thresholdCards = Int(Double(totalCards) * rules.reshuffleThreshold)
        if deck.cardsRemaining <= thresholdCards {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { // Wait for notifications to complete
                self.reshuffleDeck()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func calculateHandValue(_ hand: [Card]) -> Int {
        var value = 0
        var aces = 0
        
        // Calculate non-ace values and count aces
        for card in hand {
            switch card.rank {
            case .ace:
                aces += 1
            case .two:
                value += 2
            case .three:
                value += 3
            case .four:
                value += 4
            case .five:
                value += 5
            case .six:
                value += 6
            case .seven:
                value += 7
            case .eight:
                value += 8
            case .nine:
                value += 9
            case .ten, .jack, .queen, .king:
                value += 10
            }
        }
        
        // First add all aces as 1
        value += aces
        
        // Then try to upgrade aces to 11 if possible
        for _ in 0..<aces {
            if value + 10 <= 21 {  // +10 because we already added 1
                value += 10
            }
        }
        
        return value
    }
    
    private func checkForBlackjack() {
        guard !state.playerHands.isEmpty else {
            print("Error: No player hands for blackjack check")
            state.resolutionMessage = "Error: No player hands. Game reset."
            state.notification = ""
            state.handNotifications = []
            setPhase(.resolution)
            return
        }
        
        let playerValue = calculateHandValue(state.playerHands[0])
        let playerHasBlackjack = playerValue == 21 && state.playerHands[0].count == 2
        
        if playerHasBlackjack {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.dealerHoleCardRevealed = true
                let dealerValue = self.calculateHandValue(self.state.dealerHand)
                let dealerHasBlackjack = dealerValue == 21 && self.state.dealerHand.count == 2
                
                if dealerHasBlackjack {
                    // Both have blackjack - it's a push
                    self.state.blackjackResult = .push
                    self.state.phase = .resolution
                    let notification = ColoredNotification(text: "Push", amount: self.state.bets[0], isPositive: true, isPush: true)
                    self.state.handNotifications = [notification.formattedMessage]
                    self.analytics["pushes"] = (self.analytics["pushes"] as? Int ?? 0) + 1
                    self.state.playerBalance += self.state.bets[0] // Return original bet
                    self.setPhase(.resolution)
                } else {
                    // Only player has blackjack
                    let bet = self.state.bets[0]
                    let payout = Int(Double(bet) * self.rules.blackjackPayout)
                    
                    self.state.playerBalance += payout + bet
                    
                    self.state.phase = .resolution
                    let notification = ColoredNotification(text: "Blackjack", amount: payout, isPositive: true, isPush: false)
                    self.state.handNotifications = [notification.formattedMessage]
                    self.analytics["player_blackjacks"] = (self.analytics["player_blackjacks"] as? Int ?? 0) + 1
                    
                    
                    self.setPhase(.resolution)
                }
            }
            return
        }
        
        if state.dealerHand[0].rank == .ace || state.dealerHand[0].rank == .ten ||
            state.dealerHand[0].rank == .jack || state.dealerHand[0].rank == .queen ||
            state.dealerHand[0].rank == .king {
            isDealerCheckingHoleCard = true
            persistence.saveState(state)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isDealerCheckingHoleCard = false
                
                let dealerValue = self.calculateHandValue(self.state.dealerHand)
                let dealerHasBlackjack = dealerValue == 21 && self.state.dealerHand.count == 2
                
                if dealerHasBlackjack {
                    if self.state.insuranceAccepted {
                        let insurancePayout = self.state.insuranceBet * 2
                        self.state.playerBalance += insurancePayout
                        self.insuranceResultNotification = "Insurance Wins!\n+$\(insurancePayout)"
                        self.persistence.saveState(self.state)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.insuranceResultNotification = nil
                            self.dealerHoleCardRevealed = true
                            self.state.blackjackResult = .dealerBlackjack
                            self.state.phase = .resolution
                            let notification = ColoredNotification(text: "Dealer Blackjack", amount: self.state.bets[0], isPositive: false, isPush: false)
                            self.state.handNotifications = [notification.formattedMessage]
                            self.analytics["dealer_blackjacks"] = (self.analytics["dealer_blackjacks"] as? Int ?? 0) + 1
                            
                            self.setPhase(.resolution)
                        }
                    } else {
                        self.dealerHoleCardRevealed = true
                        self.state.blackjackResult = .dealerBlackjack
                        self.state.phase = .resolution
                        let notification = ColoredNotification(text: "Dealer Blackjack", amount: self.state.bets[0], isPositive: false, isPush: false)
                        self.state.handNotifications = [notification.formattedMessage]
                        self.analytics["dealer_blackjacks"] = (self.analytics["dealer_blackjacks"] as? Int ?? 0) + 1
                        
                        self.setPhase(.resolution)
                    }
                } else {
                    if self.state.insuranceAccepted {
                        self.insuranceResultNotification = "Insurance Lost\n-$\(self.state.insuranceBet)"
                        self.persistence.saveState(self.state)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.insuranceResultNotification = nil
                            self.setPhase(.playerTurn)
                        }
                    } else {
                        self.setPhase(.playerTurn)
                    }
                }
            }
        } else {
            self.setPhase(.playerTurn)
        }
    }
    
    func canHit() -> Bool {
        guard state.phase == .playerTurn else {
            return false
        }
        guard state.activeHandIndex < state.playerHands.count else {
            return false
        }
        
        // Don't show hit during split hand dealing
        if state.playerHands[state.activeHandIndex].count < 2 {
            return false
        }
        
        // Don't allow hit on split ace hands
        if state.splitCount > 0 {
            let hand = state.playerHands[state.activeHandIndex]
            if hand.count == 2 && hand[0].rank == .ace {
                return false
            }
        }
        
        let handValue = calculateHandValue(state.playerHands[state.activeHandIndex])
        return handValue < 21
    }
    
    func canStand() -> Bool {
        guard state.phase == .playerTurn else {
            return false
        }
        guard state.activeHandIndex < state.playerHands.count else {
            return false
        }
        
        let hand = state.playerHands[state.activeHandIndex]
        let handValue = calculateHandValue(hand)
        
        // Don't allow stand if hand has busted or is at 21
        if isHandBusted(hand) || handValue == 21 {
            return false
        }
        
        // Don't show stand during split hand dealing
        if hand.count < 2 {
            return false
        }
        
        // Don't allow stand on split ace hands
        if state.splitCount > 0 && hand.count == 2 && hand[0].rank == .ace {
            return false
        }
        
        return true
    }
    
    func canDoubleDown() -> Bool {
        guard state.phase == .playerTurn else {
            return false
        }
        guard state.activeHandIndex < state.playerHands.count else {
            return false
        }
        
        // Don't show double during split hand dealing
        if state.playerHands[state.activeHandIndex].count < 2 {
            return false
        }
        
        let hand = state.playerHands[state.activeHandIndex]
        let bet = state.bets[state.activeHandIndex]
        let handValue = calculateHandValue(hand)
        
        // Don't allow double if hand has busted or is at 21
        if isHandBusted(hand) || handValue == 21 {
            return false
        }
        
        // Don't allow double on split ace hands
        if state.splitCount > 0 && hand.count == 2 && hand[0].rank == .ace {
            return false
        }
        
        return hand.count == 2 && state.playerBalance >= bet
    }
    
    func canSplit() -> Bool {
        guard state.phase == .playerTurn else {
            return false
        }
        guard state.activeHandIndex < state.playerHands.count else {
            return false
        }
        guard state.splitCount < rules.maxSplits else {
            return false
        }
        let hand = state.playerHands[state.activeHandIndex]
        guard hand.count == 2 else {
            return false
        }
        return hand[0].rank == hand[1].rank && state.playerBalance >= state.bets[state.activeHandIndex]
    }
    
    private func isHandBusted(_ hand: [Card]) -> Bool {
        return calculateHandValue(hand) > 21
    }
    
    private func calculatePayout(playerValue: Int, dealerValue: Int, bet: Int) -> (payout: Int, notification: ColoredNotification) {
        if playerValue > 21 {
            return (0, ColoredNotification(text: "Bust", amount: bet, isPositive: false, isPush: false))
        }
        if dealerValue > 21 {
            return (bet * 2, ColoredNotification(text: "Won", amount: bet, isPositive: true, isPush: false))
        }
        if playerValue > dealerValue {
            return (bet * 2, ColoredNotification(text: "Won", amount: bet, isPositive: true, isPush: false))
        }
        if playerValue == dealerValue {
            return (bet, ColoredNotification(text: "Push", amount: bet, isPositive: true, isPush: true))
        }
        return (0, ColoredNotification(text: "Lost", amount: bet, isPositive: false, isPush: false))
    }
    
    func resetForNewRound() {
        guard state.phase == .resolution || state.phase == .betting else {
            return
        }
        if state.playerBalance <= 0 {
            state.playerBalance = 10000
        }
        state.playerHands = [[]]
        state.dealerHand = []
        state.currentBet = 0
        state.bets = []
        state.activeHandIndex = 0
        state.blackjackResult = .none
        state.resolutionMessage = ""
        state.notification = ""
        state.handNotifications = []
        setPhase(.betting)
        dealerHoleCardRevealed = false
        persistence.saveState(state)
    }
    
    var description: String {
        "BlackjackGame(phase: \(state.phase.rawValue), balance: \(state.playerBalance), cardsRemaining: \(deck.cardsRemaining))"
    }
    
    // MARK: - Insurance Methods
    
    func offerInsurance() {
        guard state.phase == .dealing else { return }
        guard let dealerUpcard = state.dealerHand.first, dealerUpcard.rank == .ace else { return }
        
        state.insuranceOffered = true
        state.notification = "Insurance? (Up to \(state.currentBet / 2))"
        persistence.saveState(state)
    }
    
    func acceptInsurance(amount: Int) {
        guard state.insuranceOffered else { return }
        guard amount > 0 && amount <= state.currentBet / 2 else { return }
        guard state.playerBalance >= amount else { return }
        
        state.insuranceBet = amount
        state.playerBalance -= amount
        state.insuranceAccepted = true
        state.insuranceOffered = false
        state.notification = ""
        persistence.saveState(state)
        
        checkForBlackjack()
    }
    
    func declineInsurance() {
        guard state.insuranceOffered else { return }
        
        state.insuranceOffered = false
        state.insuranceAccepted = false
        state.notification = ""
        persistence.saveState(state)
        
        checkForBlackjack()
    }
    
    // Public method to reset bankroll
    func resetBankroll() {
        state.playerBalance = 10000
        state.handsPlayed = 0
        isChangingBet = true
        setPhase(.clearTable)
    }
    
    // MARK: - Phase Transition Helper
    
    private func setPhase(_ newPhase: GameState.Phase) {
        state.phase = newPhase
        
        // Clear bet when entering betting phase
        if newPhase == .betting {
            state.currentBet = 0
        }
        
        // Handle clearTable phase transition
        if newPhase == .clearTable {
            handleClearTablePhase()
        }
        
        // Handle shuffle phase transition
        if newPhase == .shuffleDecks {
            handleShufflePhase()
        }
        
        // Increment handsPlayed when transitioning to .resolution from an active round, unless it's an error
        if newPhase == .resolution && isRoundActive && state.resolutionMessage.isEmpty {
            state.handsPlayed += 1
            
            // Check for bonus at 3 hands (changed from 50)
            if state.handsPlayed >= 50 {
                let bonusAmount = 25000
                state.playerBalance += bonusAmount
                state.handsPlayed = 0
                bonusNotification = "Bonus Hit\n+$\(bonusAmount)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.bonusNotification = nil
                    self.persistence.saveState(self.state)
                }
            }
        }
        
        // Start a new round when transitioning to .dealing
        if newPhase == .dealing {
            isRoundActive = true
        } else if newPhase == .resolution {
            isRoundActive = false
        }
        
        persistence.saveState(state)
    }
    
    // Public method to add to player balance (for practice mode awards, etc)
    func addToPlayerBalance(_ amount: Int) {
        state.playerBalance += amount
        persistence.saveState(state)
    }
    
    // Dedicated method to award practice bonus without affecting gameplay
    func awardPracticeBonus(amount: Int) {
        state.playerBalance += amount
        persistence.saveState(state)
    }
    
    // Add new function to handle clearTable phase transition
    private func handleClearTablePhase() {
        // This function will be called when transitioning to clearTable phase
        // The actual animation is handled in the view layer
        
        // After animation completes, clear state and transition to appropriate phase
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Clear all game state
            self.state.playerHands = [[]]
            self.state.dealerHand = []
            self.state.activeHandIndex = 0
            self.state.splitCount = 0
            self.state.notification = ""
            self.state.handNotifications = []
            self.state.blackjackResult = .none
            self.state.resolutionMessage = ""
            self.dealerHoleCardRevealed = false
            
            // Check if we need to reshuffle
            let cardsRemaining = self.deck.cardsRemaining
            let totalCards = self.rules.numDecks * 52
            let remainingPercentage = Double(cardsRemaining) / Double(totalCards)
            
            if remainingPercentage <= 0.25 {  // Reshuffle when 25% or fewer cards remain
                self.setPhase(.shuffleDecks)
            } else {
                // If not reshuffling, transition to betting phase
                if self.isChangingBet {
                    self.isChangingBet = false
                    self.setPhase(.betting)
                } else {
                    self.setPhase(.dealing)
                    self._dealInitialCards()
                }
            }
        }
    }
}

