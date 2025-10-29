import SwiftUI

struct CardView: View {
    let card: Card
    let isFaceDown: Bool
    let isTopmostFaceUp: Bool
    let shouldAnimateFlip: Bool
    let onFlipComplete: () -> Void // Callback for flip completion
    let game: BlackjackGame
    @Binding var flippedCards: Set<UUID>
    @State private var isFlipped: Bool
    @State private var flipProgress: Double = 0
    @State private var isSliding: Bool = true
    @State private var slideOffset: CGSize = CGSize(width: 300, height: -300) // Start from top-right corner
    let isSplitCard: Bool // New property to track if this card is being split
    let isHoleCard: Bool // New property to track if this is the dealer's hole card
    let isInitialAppearance: Bool // New property to control initial appearance animations
    let shouldSlideOut: Bool // New property to control slide-out animation
    
    init(card: Card, isFaceDown: Bool, isTopmostFaceUp: Bool, shouldAnimateFlip: Bool, flippedCards: Binding<Set<UUID>>, game: BlackjackGame, isSplitCard: Bool = false, isHoleCard: Bool = false, isInitialAppearance: Bool = false, shouldSlideOut: Bool = false, onFlipComplete: @escaping () -> Void = {}) {
        self.card = card
        self.isFaceDown = isFaceDown
        self.isTopmostFaceUp = isTopmostFaceUp
        self.shouldAnimateFlip = shouldAnimateFlip
        self._flippedCards = flippedCards
        self.game = game
        self._isFlipped = State(initialValue: flippedCards.wrappedValue.contains(card.id))
        self.onFlipComplete = onFlipComplete
        self.isSplitCard = isSplitCard
        self.isHoleCard = isHoleCard
        self.isInitialAppearance = isInitialAppearance
        self.shouldSlideOut = shouldSlideOut
    }
    
    var body: some View {
        ZStack {
            Image(isFaceDown || !isFlipped ? "card_back" : cardImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 180)
                .clipped()
                .rotation3DEffect(
                    .degrees(isFlipped && !isFaceDown ? 0 : 180),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .center,
                    perspective: 0.5
                )
                .scaleEffect(isFaceDown || !isFlipped ? 1.05 : 1.0) // Make facedown cards 5% larger
                .shadow(
                    color: .black.opacity(0.3),
                    radius: 1,
                    x: -1,
                    y: 0
                )
        }
        .frame(width: 120, height: 180)
        .offset(slideOffset)
        .onAppear {
            if isInitialAppearance {
                slideOffset = .zero
                if !isFaceDown {
                    isFlipped = true
                    flippedCards.insert(card.id)
                }
            } else if isHoleCard {
                if game.state.phase == .dealing {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        slideOffset = .zero
                    }
                } else {
                    slideOffset = .zero
                }
            } else if !isSplitCard {
                // Start from off-screen position
                // If this is a card being dealt to the second split hand, start further to the right
                let isSecondSplitHand = game.state.activeHandIndex == 1 && game.state.splitCount > 0
                slideOffset = CGSize(width: isSecondSplitHand ? 450 : 300, height: -300)
                // Delay the slide-in animation slightly
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        slideOffset = .zero
                    }
                }
            } else {
                slideOffset = .zero
            }
            
            if !isInitialAppearance && !isFaceDown && !flippedCards.contains(card.id) {
                let delay = 0.5
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.35)) {
                        isFlipped = true
                        flippedCards.insert(card.id)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.onFlipComplete()
                    }
                }
            }
        }
        .onChange(of: card) { _, _ in
            // Only reset animation state if this is not a split card
            if !isSplitCard {
                slideOffset = CGSize(width: 300, height: -300)
                withAnimation(.easeInOut(duration: 0.3)) {
                    slideOffset = .zero
                }
            }
        }
        .onChange(of: flippedCards) { _, newValue in
            // Update local state when flippedCards changes
            isFlipped = newValue.contains(card.id)
            
            // If flippedCards is empty, reset the animation state only for non-split cards
            if newValue.isEmpty && !isSplitCard {
                slideOffset = CGSize(width: 300, height: -300)
                withAnimation(.easeInOut(duration: 0.3)) {
                    slideOffset = .zero
                }
            }
        }
        .onChange(of: isFaceDown) { _, newValue in
            if !newValue && !flippedCards.contains(card.id) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.35)) {
                    isFlipped = true
                    flippedCards.insert(card.id)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.onFlipComplete()
                }
            }
        }
        .onChange(of: shouldAnimateFlip) { _, newValue in
            // If shouldAnimateFlip is true and the card isn't flipped yet, flip it
            if newValue && !isFaceDown && !flippedCards.contains(card.id) {
                // Add a delay before flipping the first card
                let delay = 0.5 // 0.5 seconds for all cards
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.35)) {
                        isFlipped = true
                        flippedCards.insert(card.id)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.onFlipComplete()
                    }
                }
            }
        }
        .onChange(of: shouldSlideOut) { _, newValue in
            if newValue && !isSplitCard {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.3)) {
                    slideOffset = CGSize(width: -500, height: -500)
                }
            }
        }
        .accessibilityLabel(isFaceDown ? "Dealer's hidden card" : card.description)
    }
    
    private var cardImageName: String {
        let rankNumber: Int
        switch card.rank {
        case .ace: rankNumber = 1
        case .two: rankNumber = 2
        case .three: rankNumber = 3
        case .four: rankNumber = 4
        case .five: rankNumber = 5
        case .six: rankNumber = 6
        case .seven: rankNumber = 7
        case .eight: rankNumber = 8
        case .nine: rankNumber = 9
        case .ten: rankNumber = 10
        case .jack: rankNumber = 11
        case .queen: rankNumber = 12
        case .king: rankNumber = 13
        }
        return "\(card.suit.rawValue)\(String(format: "%02d", rankNumber))"
    }
}

struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        CardView(
            card: Card(suit: .hearts, rank: .ace),
            isFaceDown: false,
            isTopmostFaceUp: true,
            shouldAnimateFlip: true,
            flippedCards: .constant([]),
            game: BlackjackGame()
        )
    }
}
