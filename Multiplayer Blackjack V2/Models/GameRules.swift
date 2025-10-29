import Foundation

struct GameRules: Codable {
    let numDecks: Int
    let blackjackPayout: Double
    let dealerHitsSoft17: Bool
    let allowDoubleDown: Bool
    let allowSplit: Bool
    let maxSplits: Int
    let allowSurrender: Bool
    let reshuffleThreshold: Double
    
    init() {
        self.numDecks = 4 // Four decks as requested
        self.blackjackPayout = 1.5
        self.dealerHitsSoft17 = false
        self.allowDoubleDown = true
        self.allowSplit = true
        self.maxSplits = 1 // Limit to one split per player
        self.allowSurrender = false
        self.reshuffleThreshold = 0.25  // Reshuffle when 25% of cards remain
    }
    
    func validate() throws {
        guard numDecks >= 1, numDecks <= 8 else {
            throw GameRulesError.invalidDeckCount
        }
        guard maxSplits >= 0 else {
            throw GameRulesError.invalidMaxSplits
        }
        guard reshuffleThreshold > 0, reshuffleThreshold <= 1 else {
            throw GameRulesError.invalidReshuffleThreshold
        }
    }
    
    enum GameRulesError: Error {
        case invalidDeckCount
        case invalidMaxSplits
        case invalidReshuffleThreshold
    }
}
