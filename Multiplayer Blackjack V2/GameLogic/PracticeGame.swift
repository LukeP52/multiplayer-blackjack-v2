import SwiftUI

class PracticeGame: ObservableObject {
    @Published private(set) var state: GameState
    @Published private(set) var deck: Deck
    @Published private(set) var consecutiveCorrect: Int = 0
    @Published private(set) var feedbackMessage: String = ""
    @Published private(set) var isCorrect: Bool = false
    @Published var isDealing: Bool = false // Track if a hand is being dealt
    @Published var dealStep: Int = 0 // 0: not started, 1: player1, 2: dealer1, 3: player2, 4: dealer2
    @Published var cardToFlip: UUID? = nil // The card that should flip now
    @Published var correctActionToFlash: BasicStrategyAction? = nil
    @Published var canShowDealButton: Bool = true
    @Published var revealDealerHoleCard: Bool = false
    @Published var shouldShowActionButtons: Bool = true // New property to control action button visibility
    @Published var isSlidingOut: Bool = false // Reintroduced for card slide-out animation
    @Published private(set) var isDealLocked: Bool = false // New property for deal lock
    
    // Add a callback to reset flipped cards in the view
    var onDealNewHand: (() -> Void)?
    // Add a callback for slide out animation
    var onSlideOut: (() -> Void)?
    
    private let blackjackGame: BlackjackGame
    private let winThreshold = 25
    
    init(blackjackGame: BlackjackGame) {
        self.state = GameState()
        self.deck = try! Deck(numDecks: 4)
        self.blackjackGame = blackjackGame
        resetForDeal()
    }
    
    func resetForDeal() {
        state.phase = .practiceDealing
        state.notification = ""
        state.handNotifications = []
        feedbackMessage = ""
        isCorrect = false
        isDealing = false
        dealStep = 0
        cardToFlip = nil
        canShowDealButton = true // Set to true initially to allow button in .practiceDealing
        isDealLocked = false // Reset the deal lock
        // Don't reset revealDealerHoleCard here
    }
    
    func handleDealButton() {
        // Check if we're in a valid state for dealing
        guard !isDealing && 
              !isDealLocked && 
              (state.phase == .practiceDealing || 
               (state.phase == .practiceFeedback && canShowDealButton)) else {
            return
        }
        
        // Lock the deal
        isDealLocked = true
        
        if state.phase == .practiceFeedback {
            clearPracticeTable()
        } else {
            startDeal()
        }
    }
    
    func startDeal() {
        state.playerHands = [[]]
        state.dealerHand = []
        isDealing = true
        dealStep = 1
        cardToFlip = nil
        revealDealerHoleCard = false  // Reset the hole card visibility
        dealNextStep()
    }
    
    // Helper to generate a random card
    private func randomCard(excluding excluded: [Card] = []) -> Card {
        var card: Card
        repeat {
            let suit = Suit.allCases.randomElement()!
            let rank = Rank.allCases.randomElement()!
            card = Card(suit: suit, rank: rank)
        } while excluded.contains(where: { $0.rank == card.rank && $0.suit == card.suit })
        return card
    }
    
    // Call this from the view after a card has finished flipping
    func dealNextStep() {
        switch dealStep {
        case 1:
            // Add player card 1 face down (random)
            let card = randomCard()
            state.playerHands[0].append(card)
            cardToFlip = card.id
            dealStep = 2
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                self.dealNextStep()
            }
        case 2:
            // Add dealer card 1 face down (random)
            let card = randomCard()
            state.dealerHand.append(card)
            cardToFlip = card.id
            dealStep = 3
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                self.dealNextStep()
            }
        case 3:
            // Add player card 2 face down, but prevent player blackjack
            var card: Card
            repeat {
                card = randomCard()
            } while (state.playerHands[0].first!.rank == .ace && card.rank.blackjackValue == 10) || (card.rank == .ace && state.playerHands[0].first!.rank.blackjackValue == 10)
            state.playerHands[0].append(card)
            cardToFlip = card.id
            dealStep = 4
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                self.dealNextStep()
            }
        case 4:
            // Add dealer card 2 face down (random, can be duplicate)
            let card = randomCard()
            state.dealerHand.append(card)
            cardToFlip = nil // Don't flip
            dealStep = 5
            // Set phase to practicePlayerChoice as soon as the last card is in position
            state.phase = .practicePlayerChoice
            isDealing = false
            onDealNewHand?()
        case 5:
            // All cards dealt, ready for player action
            cardToFlip = nil
        default:
            break
        }
    }
    
    func makeChoice(_ action: BasicStrategyAction) {
        guard state.phase == .practicePlayerChoice else { return }
        // Only use the dealer's upcard (first card)
        let correctAction = BasicStrategy.action(
            for: state.playerHands[0],
            dealerUpcard: state.dealerHand[0]
        )
        isCorrect = action == correctAction
        shouldShowActionButtons = !isCorrect // Hide buttons if correct, show if incorrect
        
        if isCorrect {
            consecutiveCorrect += 1
            if consecutiveCorrect >= winThreshold {
                feedbackMessage = "$25,000\nAdded to Bankroll!"
                blackjackGame.awardPracticeBonus(amount: 25000)  // Only update balance
                consecutiveCorrect = 0  // Reset immediately when reaching threshold
            } else {
                feedbackMessage = "Correct!"
            }
            correctActionToFlash = nil
        } else {
            consecutiveCorrect = 0
            feedbackMessage = "Incorrect"
            correctActionToFlash = correctAction
            // Clear the flash after the action buttons disappear (1.6 seconds)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                self.correctActionToFlash = nil
                self.shouldShowActionButtons = false
            }
        }
        state.phase = .practiceFeedback
        canShowDealButton = false // Set to false when entering .practiceFeedback
        
        // Reveal dealer's hole card after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.revealDealerHoleCard = true
        }
        
        // Show the deal button right when the notification disappears
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            self.feedbackMessage = "" // Clear feedback message
            self.canShowDealButton = true // Enable deal button
            self.isDealLocked = false // Release the deal lock
        }
    }
    
    func startNewHand() {
        // First transition to clearPracticeTable phase to trigger slide out
        state.phase = .clearPracticeTable
        onSlideOut?()
        
        // After slide out animation completes, transition to dealing phase
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.resetForDeal()
            self.startDeal()
        }
    }
    
    func canMakeChoice() -> Bool {
        return state.phase == .practicePlayerChoice
    }
    
    // Public hand value calculation for UI
    func calculateHandValue(_ hand: [Card]) -> Int {
        var value = 0
        var aces = 0
        for card in hand {
            if card.rank == .ace { aces += 1 }
            value += card.rank.blackjackValue
        }
        while value > 21 && aces > 0 {
            value -= 10
            aces -= 1
        }
        return value
    }
    
    func clearPracticeTable() {
        // First transition to clearPracticeTable phase to trigger slide out
        state.phase = .clearPracticeTable
        isSlidingOut = true // Set isSlidingOut to true
        onSlideOut?()
        
        // After slide out animation completes, transition to dealing phase and start dealing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.resetForDeal()
            self.startDeal() // Automatically start dealing after reset
        }
    }
}
