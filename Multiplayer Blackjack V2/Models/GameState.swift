import Foundation

enum BlackjackResult: String, Codable {
    case none
    case playerBlackjack
    case dealerBlackjack
    case push
}

struct GameState: Codable {
    enum Phase: String, Codable {
        case betting
        case dealing
        case playerTurn
        case dealerTurn
        case resolution
        case clearTable // New phase for sliding out cards
        case practiceDealing // New practice-specific phase
        case practicePlayerChoice // New practice-specific phase
        case practiceFeedback // New practice-specific phase
        case clearPracticeTable // New phase for practice mode slide out
        case shuffleDecks // New phase for deck reshuffling
    }
    
    var phase: Phase
    var playerHands: [[Card]]
    var dealerHand: [Card]
    var currentBet: Int
    var initialBet: Int
    var playerBalance: Int
    var blackjackResult: BlackjackResult
    var activeHandIndex: Int
    var bets: [Int]
    var resolutionMessage: String
    var notification: String
    var handNotifications: [String] // Per-hand notifications
    var splitCount: Int
    var insuranceBet: Int
    var insuranceOffered: Bool
    var insuranceAccepted: Bool
    var handsPlayed: Int
    var completedHands: [Int]
    
    init() {
        phase = .betting
        playerHands = [[]]
        dealerHand = []
        currentBet = 0
        initialBet = 0
        playerBalance = 10000
        blackjackResult = .none
        activeHandIndex = 0
        bets = []
        resolutionMessage = ""
        notification = ""
        handNotifications = []
        splitCount = 0
        insuranceBet = 0
        insuranceOffered = false
        insuranceAccepted = false
        handsPlayed = 0
        completedHands = []
    }
}
