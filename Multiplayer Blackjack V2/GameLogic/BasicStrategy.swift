import Foundation

/// Possible basic strategy actions
enum BasicStrategyAction: String {
    case hit = "H"
    case stand = "S"
    case double = "D"
    case split = "Y"
}

struct BasicStrategy {
    /// Returns the correct basic strategy action for the given hand and dealer upcard.
    /// - Parameters:
    ///   - playerHand: The player's cards
    ///   - dealerUpcard: The dealer's upcard
    ///   - canDouble: Whether doubling is allowed (for split hands, etc)
    /// - Returns: The recommended action
    static func action(for playerHand: [Card], dealerUpcard: Card, canDouble: Bool = true) -> BasicStrategyAction {
        guard playerHand.count >= 2 else { return .hit }
        let dealerValue = dealerUpcard.rank.blackjackValue
        let isPair = playerHand.count == 2 && playerHand[0].rank == playerHand[1].rank
        let isSoft = playerHand.contains(where: { $0.rank == .ace }) && handValue(playerHand) <= 21 && handValue(playerHand) != hardValue(playerHand)
        let handTotal = handValue(playerHand)
        
        // PAIR SPLITTING
        if isPair {
            let pairRank = playerHand[0].rank
            switch pairRank {
            case .ace: return .split
            case .ten: return .stand
            case .nine:
                if (2...6).contains(dealerValue) || dealerValue == 8 || dealerValue == 9 { return .split }
                else { return .stand }
            case .eight: return .split
            case .seven:
                if (2...7).contains(dealerValue) { return .split }
                else { return .hit }
            case .six:
                if (2...6).contains(dealerValue) { return .split }
                else { return .hit }
            case .five:
                if (2...9).contains(dealerValue) && canDouble { return .double }
                else { return .hit }
            case .four:
                if (5...6).contains(dealerValue) { return .split }
                else { return .hit }
            case .three, .two:
                if (2...7).contains(dealerValue) { return .split }
                else { return .hit }
            default: break
            }
        }
        
        // SOFT TOTALS
        if isSoft {
            let nonAceTotal = playerHand.reduce(0) { $0 + ($1.rank == .ace ? 0 : $1.rank.blackjackValue) }
            switch nonAceTotal {
            case 9: return .stand // A,9
            case 8: return .stand // A,8
            case 7:
                if (3...6).contains(dealerValue) && canDouble { return .double }
                else if (2...8).contains(dealerValue) { return .stand }
                else { return .hit }
            case 6:
                if (3...6).contains(dealerValue) && canDouble { return .double }
                else { return .hit }
            case 5:
                if (4...6).contains(dealerValue) && canDouble { return .double }
                else { return .hit }
            case 4:
                if (4...6).contains(dealerValue) && canDouble { return .double }
                else { return .hit }
            case 3:
                if (5...6).contains(dealerValue) && canDouble { return .double }
                else { return .hit }
            case 2:
                if (5...6).contains(dealerValue) && canDouble { return .double }
                else { return .hit }
            default: break
            }
        }
        
        // HARD TOTALS
        switch handTotal {
        case 17...21: return .stand
        case 16, 15:
            if (2...6).contains(dealerValue) { return .stand }
            else { return .hit }
        case 14, 13:
            if (2...6).contains(dealerValue) { return .stand }
            else { return .hit }
        case 12:
            if (4...6).contains(dealerValue) { return .stand }
            else { return .hit }
        case 11:
            if canDouble { return .double } else { return .hit }
        case 10:
            if (2...9).contains(dealerValue) && canDouble { return .double } else { return .hit }
        case 9:
            if (3...6).contains(dealerValue) && canDouble { return .double } else { return .hit }
        default:
            return .hit
        }
    }
    
    private static func handValue(_ hand: [Card]) -> Int {
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
    
    private static func hardValue(_ hand: [Card]) -> Int {
        // Count all aces as 1
        return hand.reduce(0) { $0 + ($1.rank == .ace ? 1 : $1.rank.blackjackValue) }
    }
}

// Helper for Rank to get blackjack value
extension Rank {
    var blackjackValue: Int {
        switch self {
        case .ace: return 11
        case .two: return 2
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case .seven: return 7
        case .eight: return 8
        case .nine: return 9
        case .ten, .jack, .queen, .king: return 10
        }
    }
} 