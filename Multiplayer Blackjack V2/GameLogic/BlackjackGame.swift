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
        print("Loaded balance: \(state.playerBalance), currentBet: \(state.currentBet)")
        if state.playerBalance <= 0 {
            print("Insufficient balance. Resetting to default.")
            state.playerBalance = 10000
        }
        print("Final balance after setup: \(state.playerBalance)")
        
        setPhase(.betting)
        
        analytics["games_started"] = (analytics["games_started"] as? Int ?? 0) + 1
        print("Analytics: \(analytics)")
        
        persistence.saveState(state)
        print("Game setup complete: \(deck.cardsRemaining) cards, balance: \(state.playerBalance)")
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
        print("Predefined cards set - Player: \(playerCards?.map { $0.description } ?? []), Dealer: \(dealerCards?.map { $0.description } ?? [])")
    }
    
    // MARK: - Betting Phase Methods
    
    func addToBet(amount: Int) {
        let newBet = state.currentBet + amount
        if newBet <= state.playerBalance && newBet > 0 {
            state.currentBet = newBet
            print("Bet added: \(amount), currentBet: \(state.currentBet), balance: \(state.playerBalance)")
            persistence.saveState(state)
        } else {
            print("Cannot add bet: \(amount). Exceeds balance (\(state.playerBalance)) or invalid.")
        }
    }
    
    func clearBet() {
        state.currentBet = 0
        print("Bet cleared: currentBet: \(state.currentBet), balance: \(state.playerBalance)")
        persistence.saveState(state)
    }
    
    var isBetValid: Bool {
        let valid = state.currentBet > 0 && state.currentBet <= state.playerBalance
        print("Checking isBetValid: \(valid), currentBet: \(state.currentBet), balance: \(state.playerBalance)")
        return valid
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
            print("Cannot confirm bet: Not in betting phase (\(state.phase.rawValue))")
            return
        }
        guard isBetValid else {
            print("Cannot confirm bet: \(betValidationMessage)")
            return
        }
        
        state.playerBalance -= state.currentBet
        state.initialBet = state.currentBet
        state.bets = [state.currentBet]
        print("Bet confirmed: \(state.currentBet), initialBet: \(state.initialBet), new balance: \(state.playerBalance), bets: \(state.bets)")
        
        let totalBets = (analytics["total_bets"] as? Int ?? 0) + 1
        let totalBetAmount = (analytics["average_bet"] as? Double ?? 0) * Double(totalBets - 1) + Double(state.currentBet)
        analytics["total_bets"] = totalBets
        analytics["average_bet"] = totalBetAmount / Double(totalBets)
        print("Analytics updated: \(analytics)")
        
        setPhase(.dealing)
        dealCards()
    }
    
    func repeatBet() {
        if let lastTime = lastActionTime, Date().timeIntervalSince(lastTime) < 1.0 {
            print("Action ignored: Repeat Bet - Less than 1 second since last action (\(Date().timeIntervalSince(lastTime)) seconds)")
            return
        }
        lastActionTime = Date()
        
        guard state.phase == .resolution else {
            print("Repeat bet blocked: Not in resolution phase, current phase: \(state.phase.rawValue)")
            return
        }
        
        // Only allow repeat bet if player has enough balance
        if state.currentBet > state.playerBalance {
            print("Repeat bet blocked: Not enough balance. Current bet: \(state.currentBet), balance: \(state.playerBalance)")
            return
        }
        
        // Deduct the bet from the balance for repeat bet immediately
        state.playerBalance -= state.currentBet
        
        // Transition to clearTable phase first
        setPhase(.clearTable)
        
        // The state will be cleared in handleClearTablePhase after the animation completes
        print("Repeated bet: Transitioned to clearTable phase, currentBet: \(state.currentBet)")
        persistence.saveState(state)
    }
    
    func changeBet() {
        if let lastTime = lastActionTime, Date().timeIntervalSince(lastTime) < 1.0 {
            print("Action ignored: Change Bet - Less than 1 second since last action (\(Date().timeIntervalSince(lastTime)) seconds)")
            return
        }
        lastActionTime = Date()
        
        guard state.phase == .resolution else {
            print("Change bet blocked: Not in resolution phase, current phase: \(state.phase.rawValue)")
            return
        }
        
        // Set flag before transitioning to clearTable
        isChangingBet = true
        
        // Transition to clearTable phase first
        setPhase(.clearTable)
        
        // The state will be cleared in handleClearTablePhase after the animation completes
        print("Change bet: Transitioned to clearTable phase")
        persistence.saveState(state)
    }
    
    func quitGame() {
        persistence.saveState(state)
        print("Game exited. Balance saved: \(state.playerBalance)")
        state = GameState()
        setup()
    }
    
    func allIn() {
        state.currentBet = state.playerBalance
        print("All In: currentBet set to \(state.currentBet)")
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
                    print("Deck reshuffled! New card count: \(self.deck.cardsRemaining)")
                } catch {
                    print("Deck reshuffle failed: \(error)")
                    self.deck = try! Deck(numDecks: 1)
                    print("Fallback to single deck. New card count: \(self.deck.cardsRemaining)")
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
        print("Entering shuffle phase")
        
        // Show the shuffle view immediately
        self.isReshuffling = true
        self.state.notification = "Reshuffling Deck..."
        self.persistence.saveState(self.state)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            do {
                self.deck = try Deck(numDecks: self.rules.numDecks)
                print("Deck reshuffled! New card count: \(self.deck.cardsRemaining)")
            } catch {
                print("Deck reshuffle failed: \(error)")
                self.deck = try! Deck(numDecks: 1)
                print("Fallback to single deck. New card count: \(self.deck.cardsRemaining)")
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
        print("Starting dealCards, current phase: \(state.phase.rawValue), cards remaining: \(deck.cardsRemaining), playerHands: \(state.playerHands.count), activeHandIndex: \(state.activeHandIndex)")
        
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
        print("State initialized for dealing: playerHands: \(state.playerHands.count), activeHandIndex: \(state.activeHandIndex), bets: \(state.bets)")
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
            print("Dealt player card 1: \(card.description)")
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
            print("Dealt dealer card 1: \(card.description)")
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
            print("Dealt player card 2: \(card.description)")
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
            print("Dealt dealer card 2: \(card.description)")
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
            print("Action ignored: Hit - Less than 1 second since last action (\(Date().timeIntervalSince(lastTime)) seconds)")
            return
        }
        lastActionTime = Date()
        
        print("[DEBUG] hit() called for hand \(state.activeHandIndex), phase: \(state.phase), hand: \(state.playerHands[state.activeHandIndex].map { $0.description })")
        let handDesc = state.playerHands.map { $0.map { $0.description }.joined(separator: ", ") }.joined(separator: " | ")
        print("Hit initiated for hand \(state.activeHandIndex + 1), phase: \(state.phase.rawValue), activeHandIndex: \(state.activeHandIndex), hands count: \(state.playerHands.count), bets: \(state.bets), playerHands: [\(handDesc)]")
        
        guard state.phase == .playerTurn else {
            print("Hit blocked: Incorrect phase: \(state.phase.rawValue), expected playerTurn")
            return
        }
        
        if state.activeHandIndex >= state.playerHands.count && !state.playerHands.isEmpty {
            print("Hit warning: Invalid activeHandIndex: \(state.activeHandIndex), resetting to 0")
            state.activeHandIndex = 0
        }
        guard state.activeHandIndex < state.playerHands.count else {
            print("Hit blocked: Invalid hand index: \(state.activeHandIndex), hands count: \(state.playerHands.count)")
            return
        }
        guard !state.playerHands[state.activeHandIndex].isEmpty else {
            print("Hit blocked: Empty hand at index: \(state.activeHandIndex)")
            return
        }
        
        let handValue = calculateHandValue(state.playerHands[state.activeHandIndex])
        print("[DEBUG] Current handValue before hit: \(handValue)")
        guard handValue < 21 else {
            print("[DEBUG] Hit blocked: Hand value \(handValue) is 21 or above for hand \(state.activeHandIndex + 1)")
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
        print("[DEBUG] After hit, newHandValue: \(newHandValue) (type: \(type(of: newHandValue)))")
        
        analytics["hits"] = (analytics["hits"] as? Int ?? 0) + 1
        persistence.saveState(state)
        
        if isHandBusted(state.playerHands[state.activeHandIndex]) {
            print("[DEBUG] Hand busted branch")
            if state.handNotifications.count != state.playerHands.count {
                state.handNotifications = Array(repeating: "", count: state.playerHands.count)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.state.handNotifications[self.state.activeHandIndex] = "Bust\n-$\(self.state.bets[self.state.activeHandIndex])"
                print("Hand \(self.state.activeHandIndex + 1) busted: \(newHandValue). Notification set to: Bust\n-$\(self.state.bets[self.state.activeHandIndex])")
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
                print("[DEBUG] Hand reached 21, calling advanceToNextHandOrResolve()")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.advanceToNextHandOrResolve()
                }
                return
            }
        }
        
        print("[DEBUG] Hand did not bust or reach 21, value: \(newHandValue)")
        // Don't change phase, stay in playerTurn
    }
    
    func stand() {
        if let lastTime = lastActionTime, Date().timeIntervalSince(lastTime) < 1.0 {
            print("Action ignored: Stand - Less than 1 second since last action (\(Date().timeIntervalSince(lastTime)) seconds)")
            return
        }
        lastActionTime = Date()
        
        let handDesc = state.playerHands.map { $0.map { $0.description }.joined(separator: ", ") }.joined(separator: " | ")
        print("Stand initiated for hand \(state.activeHandIndex + 1), phase: \(state.phase.rawValue), activeHandIndex: \(state.activeHandIndex), hands count: \(state.playerHands.count), playerHands: [\(handDesc)], bets: \(state.bets)")
        
        guard state.phase == .playerTurn else {
            print("Stand blocked: Incorrect phase: \(state.phase.rawValue), expected playerTurn")
            return
        }
        
        guard state.activeHandIndex < state.playerHands.count else {
            print("Stand blocked: Invalid hand index: \(state.activeHandIndex), hands count: \(state.playerHands.count)")
            return
        }
        
        print("Stand completed on hand \(state.activeHandIndex + 1): \(state.playerHands[state.activeHandIndex].map { $0.description }.joined(separator: ", "))")
        
        analytics["stands"] = (analytics["stands"] as? Int ?? 0) + 1
        persistence.saveState(state)
        
        print("Stand advancing to dealer turn or next hand...")
        setPhase(.playerTurn)
        advanceToNextHandOrResolve()
    }
    
    func doubleDown() {
        if let lastTime = lastActionTime, Date().timeIntervalSince(lastTime) < 1.0 {
            print("Action ignored: Double - Less than 1 second since last action (\(Date().timeIntervalSince(lastTime)) seconds)")
            return
        }
        lastActionTime = Date()
        
        let handDesc = state.playerHands.map { $0.map { $0.description }.joined(separator: ", ") }.joined(separator: " | ")
        print("Double initiated for hand \(state.activeHandIndex + 1), phase: \(state.phase.rawValue), activeHandIndex: \(state.activeHandIndex), hands count: \(state.playerHands.count), playerHands: [\(handDesc)], bets: \(state.bets)")
        
        guard state.phase == .playerTurn else {
            print("Double blocked: Incorrect phase: \(state.phase.rawValue), expected playerTurn")
            return
        }
        
        guard state.activeHandIndex < state.playerHands.count else {
            print("Double blocked: Invalid hand index: \(state.activeHandIndex), hands count: \(state.playerHands.count)")
            return
        }
        
        guard state.playerHands[state.activeHandIndex].count == 2 else {
            print("Double blocked: Hand does not have exactly 2 cards: \(state.playerHands[state.activeHandIndex].count)")
            return
        }
        
        guard state.playerBalance >= state.bets[state.activeHandIndex] else {
            print("Double blocked: Insufficient balance: \(state.playerBalance), needed: \(state.bets[state.activeHandIndex])")
            return
        }
        
        print("Drawing card for double, cards remaining: \(deck.cardsRemaining)")
        guard let card = deck.draw() else {
            print("Error: Failed to draw card for double down, cards remaining: \(deck.cardsRemaining)")
            state.resolutionMessage = "Error: Card draw failed. Game reset."
            state.notification = ""
            state.handNotifications = []
            setPhase(.resolution)
            return
        }
        
        print("Card drawn for double: \(card.description)")
        state.playerBalance -= state.bets[state.activeHandIndex]
        state.bets[state.activeHandIndex] *= 2
        state.playerHands[state.activeHandIndex].append(card)
        
        let newHandValue = calculateHandValue(state.playerHands[state.activeHandIndex])
        print("Double completed: Hand \(state.activeHandIndex + 1), added card: \(card.description), new bet: \(state.bets[state.activeHandIndex]), new balance: \(state.playerBalance), new hand value: \(newHandValue). Hand: \(state.playerHands[state.activeHandIndex].map { $0.description }.joined(separator: ", "))")
        
        analytics["doubles"] = (analytics["doubles"] as? Int ?? 0) + 1
        persistence.saveState(state)
        
        if isHandBusted(state.playerHands[state.activeHandIndex]) {
            if state.handNotifications.count != state.playerHands.count {
                state.handNotifications = Array(repeating: "", count: state.playerHands.count)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.state.handNotifications[self.state.activeHandIndex] = "Bust\n-$\(self.state.bets[self.state.activeHandIndex])"
                print("Hand \(self.state.activeHandIndex + 1) busted after double: \(newHandValue). Notification set to: Bust\n-$\(self.state.bets[self.state.activeHandIndex])")
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
            print("Split blocked: Cannot split")
            return
        }
        
        print("Split initiated for hand \(state.activeHandIndex + 1), phase: \(state.phase.rawValue), activeHandIndex: \(state.activeHandIndex), hands count: \(state.playerHands.count), playerHands: \(state.playerHands.map { $0.map { $0.description }.joined(separator: ", ") }.joined(separator: " | ")), bets: \(state.bets)")
        
        let currentHand = state.playerHands[state.activeHandIndex]
        let secondCard = currentHand[1]
        
        state.playerHands[state.activeHandIndex] = [currentHand[0]]
        state.playerHands.append([secondCard])
        
        state.playerBalance -= state.bets[state.activeHandIndex]
        state.bets.append(state.bets[state.activeHandIndex])
        state.splitCount += 1
        
        let isSplittingAces = currentHand[0].rank == .ace
        print("Split completed. New hands: \(state.playerHands.map { $0.map { $0.description }.joined(separator: ", ") }.joined(separator: " | ")), Bets: \(state.bets), Balance: \(state.playerBalance), Split count: \(state.splitCount), Splitting aces: \(isSplittingAces)")
        
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
            print("Split draw for hand 0: \(card.description). Hand: \(self.state.playerHands[0].map { $0.description }.joined(separator: ", "))")
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
                    print("Split draw for hand 1: \(secondCard.description). Hand: \(self.state.playerHands[1].map { $0.description }.joined(separator: ", "))")
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
        print("[DEBUG] advanceToNextHandOrResolve called. activeHandIndex: \(state.activeHandIndex), playerHands.count: \(state.playerHands.count)")
        let allHandsBusted = state.playerHands.allSatisfy { isHandBusted($0) }
        if allHandsBusted {
            print("[DEBUG] All hands have busted, moving to resolution")
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
            print("[DEBUG] Only one hand, moving to dealer turn.")
            setPhase(.dealerTurn)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.playDealerTurn()
            }
        } else if state.activeHandIndex < state.playerHands.count - 1 {
            state.activeHandIndex += 1
            print("[DEBUG] Moving to next split hand: activeHandIndex is now \(state.activeHandIndex)")
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
                    print("Dealt second card to split hand \(self.state.activeHandIndex + 1): \(card.description)")
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
            print("[DEBUG] All split hands played, moving to dealer turn.")
            setPhase(.dealerTurn)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.playDealerTurn()
            }
        }
    }
    
    private func playDealerTurn() {
        print("Starting dealer turn...")
        setPhase(.dealerTurn)
        let initialValue = calculateHandValue([state.dealerHand[0]])
        print("Dealer turn started: Upcard: \(state.dealerHand[0].description), initial value: \(initialValue)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.dealerHoleCardRevealed = true
            self.persistence.saveState(self.state)
            
            let revealedValue = self.calculateHandValue(self.state.dealerHand)
            print("Dealer revealed hole card: \(self.state.dealerHand[1].description), total value: \(revealedValue)")
            
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
        print("Dealer continuing turn, current value: \(dealerValue), hand: \(state.dealerHand.map { $0.description }.joined(separator: ", "))")
        
        if dealerValue < 17 {
            print("Dealer must hit, value: \(dealerValue) < 17")
            guard let card = deck.draw() else {
                print("Error: Deck empty during dealer draw")
                state.resolutionMessage = "Error: Dealer deck empty. Game reset."
                state.notification = ""
                state.handNotifications = []
                setPhase(.resolution)
                return
            }
            
            state.dealerHand.append(card)
            let newValue = calculateHandValue(state.dealerHand)
            print("Dealer draws: \(card.description), new value: \(dealerValue) - \(newValue). Hand: \(state.dealerHand.map { $0.description }.joined(separator: ", "))")
            persistence.saveState(state)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                self.continueDealerTurn()
            }
        } else {
            print("Dealer stands at \(dealerValue)")
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
            print("Resolve blocked: Not in dealerTurn phase, current phase: \(state.phase.rawValue)")
            return
        }
        print("Resolving round: Dealer hand: \(state.dealerHand.map { $0.description }.joined(separator: ", ")), value: \(dealerValue)")
        
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
            print("Hand \(index + 1): Player value: \(playerValue) vs Dealer: \(dealerValue) - \(outcome.notification.formattedMessage), Payout: \(outcome.payout), Bet: \(bet)")
        }
        
        state.playerBalance += totalPayout
        setPhase(.resolution)
        print("Round resolved: Total payout: \(totalPayout), New balance: \(state.playerBalance), Hand Notifications: \(state.handNotifications)")
        
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
        let handDesc = state.playerHands.map { $0.map { $0.description }.joined(separator: ", ") }.joined(separator: " | ")
        print("Checking for blackjack, player hands: \(state.playerHands.count), dealer hand: \(state.dealerHand.count), playerHand[0]: \(state.playerHands.first?.map { $0.description }.joined(separator: ", ") ?? "empty"), all hands: [\(handDesc)]")
        
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
            print("Player has blackjack! Checking dealer...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.dealerHoleCardRevealed = true
                let dealerValue = self.calculateHandValue(self.state.dealerHand)
                let dealerHasBlackjack = dealerValue == 21 && self.state.dealerHand.count == 2
                
                if dealerHasBlackjack {
                    // Both have blackjack - it's a push
                    print("Both player and dealer have blackjack - Push")
                    self.state.blackjackResult = .push
                    self.state.phase = .resolution
                    let notification = ColoredNotification(text: "Push", amount: self.state.bets[0], isPositive: true, isPush: true)
                    self.state.handNotifications = [notification.formattedMessage]
                    self.analytics["pushes"] = (self.analytics["pushes"] as? Int ?? 0) + 1
                    self.state.playerBalance += self.state.bets[0] // Return original bet
                    self.setPhase(.resolution)
                } else {
                    // Only player has blackjack
                    print("Only player has blackjack! Calculating payout...")
                    let bet = self.state.bets[0]
                    let payout = Int(Double(bet) * self.rules.blackjackPayout)
                    print("Blackjack payout calculation: bet=\(bet), multiplier=\(self.rules.blackjackPayout), payout=\(payout)")
                    
                    self.state.playerBalance += payout + bet
                    print("Updated balance after blackjack: \(self.state.playerBalance)")
                    
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
            print("Dealer checking hole card...")
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
                        print("[DEBUG] Insurance win notification set: \(self.insuranceResultNotification ?? "nil")")
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
                        print("[DEBUG] Insurance lost notification set: \(self.insuranceResultNotification ?? "nil")")
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
            print("Reset blocked: Not in resolution or betting phase, current phase: \(state.phase.rawValue)")
            return
        }
        if state.playerBalance <= 0 {
            print("Player out of money. Resetting balance to $10,000.")
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
        print("Reset for new round completed. Balance: \(state.playerBalance), currentBet: \(state.currentBet), phase: \(state.phase.rawValue)")
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
        let oldPhase = state.phase
        state.phase = newPhase
        print("Phase changed from \(oldPhase.rawValue) to \(newPhase.rawValue)")
        
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
            print("Hand count incremented: handsPlayed = \(state.handsPlayed)")
            
            // Check for bonus at 3 hands (changed from 50)
            if state.handsPlayed >= 50 {
                let bonusAmount = 25000
                state.playerBalance += bonusAmount
                state.handsPlayed = 0
                bonusNotification = "Bonus Hit\n+$\(bonusAmount)"
                print("Bonus awarded: +$\(bonusAmount), new balance: \(state.playerBalance), handsPlayed reset to \(state.handsPlayed)")
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
        print("Entering clearTable phase")
        
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
                print("Cards remaining below threshold (\(remainingPercentage * 100)%): \(cardsRemaining)/\(totalCards)")
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

