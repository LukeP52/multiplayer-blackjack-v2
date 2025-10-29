import Foundation

enum Suit: String, CaseIterable, Codable {
    case hearts = "Hearts"
    case diamonds = "Diamonds"
    case clubs = "Clubs"
    case spades = "Spades"
}

enum Rank: String, CaseIterable, Codable {
    case ace = "Ace"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case ten = "10"
    case jack = "Jack"
    case queen = "Queen"
    case king = "King"
}

struct Card: Identifiable, Codable, Equatable {
    var id: UUID
    let suit: Suit
    let rank: Rank
    
    var description: String {
        "\(rank.rawValue) of \(suit.rawValue)"
    }
    
    init(id: UUID = UUID(), suit: Suit, rank: Rank) {
        self.id = id
        self.suit = suit
        self.rank = rank
    }
    
    // Implement Equatable by comparing id, suit, and rank
    static func == (lhs: Card, rhs: Card) -> Bool {
        return lhs.id == rhs.id && lhs.suit == rhs.suit && lhs.rank == rhs.rank
    }
}
