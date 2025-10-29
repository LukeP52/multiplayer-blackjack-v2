import Foundation

struct Deck {
    private var cards: [Card]
    var cardsRemaining: Int {
        cards.count
    }
    
    init(numDecks: Int) throws {
        guard numDecks > 0 else {
            throw NSError(domain: "DeckError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Number of decks must be positive"])
        }
        cards = []
        for _ in 0..<numDecks {
            for suit in Suit.allCases {
                for rank in Rank.allCases {
                    cards.append(Card(suit: suit, rank: rank))
                }
            }
        }
        cards.shuffle()
    }
    
    mutating func draw() -> Card? {
        guard !cards.isEmpty else { return nil }
        return cards.removeLast()
    }
    
    // New method to remove specific cards
    mutating func removeCards(_ cardsToRemove: [Card]) {
        for card in cardsToRemove {
            if let index = cards.firstIndex(where: { $0.rank == card.rank && $0.suit == card.suit }) {
                cards.remove(at: index)
            }
        }
    }
    
    // Public method to return a card to the deck (for practice mode)
    mutating func returnCard(_ card: Card) {
        cards.append(card)
    }
}
