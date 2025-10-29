import SwiftUI

struct BlackjackDealingView: View {
    @ObservedObject var game: BlackjackGame
    @Binding var flippedCards: Set<UUID>
    @Binding var flippedCardCounts: [Int: Int]
    var isSlidingOut: Bool
    var isInitialAppearance: Bool
    var showHandTotals: Bool

    var body: some View {
        ZStack {
            // Fixed position elements
            VStack(spacing: 40) {
                // Dealer's hand (hidden during betting)
                if game.state.phase != .betting {
                    VStack(spacing: 8) {
                        let visibleDealerCards = game.state.dealerHand.enumerated().filter { index, card in
                            if index == 1 && !game.dealerHoleCardRevealed {
                                return false
                            }
                            return flippedCards.contains(card.id) || (index == 1 && game.dealerHoleCardRevealed)
                        }.map { $0.1 }
                        let dealerValue = visibleDealerCards.isEmpty ? nil : game.calculateHandValue(visibleDealerCards)
                        if let value = dealerValue, showHandTotals {
                            Text("\(value)")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                                .frame(height: 30)
                        } else {
                            Spacer().frame(height: 30)
                        }
                        ZStack {
                            ForEach(game.state.dealerHand.indices, id: \.self) { index in
                                let card = game.state.dealerHand[index]
                                let isTopmost = index == game.state.dealerHand.count - 1
                                let isHoleCard = index == 1 && !game.dealerHoleCardRevealed
                                CardView(
                                    card: card,
                                    isFaceDown: isHoleCard,
                                    isTopmostFaceUp: isTopmost && !isHoleCard,
                                    shouldAnimateFlip: isHoleCard ? game.dealerHoleCardRevealed : !flippedCards.contains(card.id),
                                    flippedCards: $flippedCards,
                                    game: game,
                                    isHoleCard: isHoleCard,
                                    isInitialAppearance: isInitialAppearance,
                                    shouldSlideOut: isSlidingOut,
                                    onFlipComplete: {
                                        flippedCardCounts[-1, default: 0] += 1
                                    }
                                )
                                .offset(x: CGFloat(index * 25), y: isHoleCard ? (game.isDealerCheckingHoleCard ? -30 : 0) : 0)
                                .animation(.easeInOut(duration: 0.3), value: game.isDealerCheckingHoleCard)
                                .zIndex(Double(index))
                            }
                        }
                        .frame(width: 170, height: 180)
                    }
                    .frame(height: 218)
                }
                // Player's hands (hidden during betting)
                if game.state.phase != .betting {
                    VStack(spacing: 8) {
                        if game.state.playerHands.count > 1 {
                            // Split hands layout
                            HStack(spacing: 20) {
                                ForEach(game.state.playerHands.indices.reversed(), id: \.self) { handIndex in
                                    let visibleCards = game.state.playerHands[handIndex].filter { flippedCards.contains($0.id) }
                                    let handValue = visibleCards.isEmpty ? nil : game.calculateHandValue(visibleCards)
                                    let bet = game.state.bets[handIndex]
                                    let cardCount = game.state.playerHands[handIndex].count
                                    let totalCardWidth = cardCount == 1 ? 120 : (120 + (cardCount - 1) * 15)
                                    let centerOffset = CGFloat(totalCardWidth - 120) / 2
                                    VStack(spacing: 8) {
                                        if let value = handValue, showHandTotals {
                                            Text("\(value)")
                                                .font(.system(size: 26, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(height: 30)
                                        } else {
                                            Spacer().frame(height: 30)
                                        }
                                        ZStack {
                                            ForEach(game.state.playerHands[handIndex].indices, id: \.self) { index in
                                                let card = game.state.playerHands[handIndex][index]
                                                let isTopmost = index == game.state.playerHands[handIndex].count - 1
                                                let cardOffset = CGFloat(index * 15)
                                                let isSplitCard = index == 0 && game.state.splitCount > 0 && !isSlidingOut
                                                let isNewCard = index == game.state.playerHands[handIndex].count - 1 && !flippedCards.contains(card.id)
                                                CardView(
                                                    card: card,
                                                    isFaceDown: false,
                                                    isTopmostFaceUp: isTopmost,
                                                    shouldAnimateFlip: !flippedCards.contains(card.id),
                                                    flippedCards: $flippedCards,
                                                    game: game,
                                                    isSplitCard: isSplitCard,
                                                    isInitialAppearance: isInitialAppearance,
                                                    shouldSlideOut: isSlidingOut,
                                                    onFlipComplete: {
                                                        flippedCardCounts[handIndex, default: 0] += 1
                                                    }
                                                )
                                                .offset(x: cardOffset - centerOffset, y: 0)
                                                .animation(
                                                    isNewCard ? 
                                                        .spring(response: 0.4, dampingFraction: 0.7) :
                                                        .spring(response: 0.3, dampingFraction: 0.7).delay(0.2),
                                                    value: cardOffset
                                                )
                                                .animation(
                                                    isNewCard ? 
                                                        .spring(response: 0.4, dampingFraction: 0.7) :
                                                        .spring(response: 0.3, dampingFraction: 0.7).delay(0.2),
                                                    value: centerOffset
                                                )
                                                .zIndex(isSlidingOut ? 100 : (isSplitCard ? 0 : Double(index)))
                                            }
                                        }
                                        .frame(width: 170, height: 180)
                                        if game.state.phase != .clearTable {
                                            Text("Bet: $\(bet)")
                                                .font(.system(size: 26, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(height: 30)
                                        }
                                    }
                                    .opacity(1.0)
                                    .zIndex(Double(handIndex))
                                }
                            }
                            // Show centered bet only if in clearTable and not changing bet
                            if game.state.phase == .clearTable && !game.isChangingBet {
                                GeometryReader { geometry in
                                    Text("Bet: $\(game.state.initialBet)")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(height: 30)
                                        .frame(maxWidth: .infinity)
                                        .position(x: geometry.size.width / 2, y: 15)
                                }
                                .frame(height: 30)
                            }
                        } else {
                            // Single hand layout
                            let visibleCards = game.state.playerHands[0].filter { flippedCards.contains($0.id) }
                            let handValue = visibleCards.isEmpty ? nil : game.calculateHandValue(visibleCards)
                            let bet = game.state.bets.first ?? 0
                            VStack(spacing: 8) {
                                if let value = handValue, showHandTotals {
                                    Text("\(value)")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(height: 30)
                                } else {
                                    Spacer().frame(height: 30)
                                }
                                ZStack {
                                    ForEach(game.state.playerHands[0].indices, id: \.self) { index in
                                        let card = game.state.playerHands[0][index]
                                        let isTopmost = index == game.state.playerHands[0].count - 1
                                        CardView(
                                            card: card,
                                            isFaceDown: false,
                                            isTopmostFaceUp: isTopmost,
                                            shouldAnimateFlip: !flippedCards.contains(card.id),
                                            flippedCards: $flippedCards,
                                            game: game,
                                            isInitialAppearance: isInitialAppearance,
                                            shouldSlideOut: isSlidingOut,
                                            onFlipComplete: {
                                                flippedCardCounts[0, default: 0] += 1
                                            }
                                        )
                                        .offset(x: CGFloat(index * 25), y: 0)
                                        .zIndex(Double(index))
                                    }
                                }
                                .frame(width: 170, height: 180)
                                .zIndex(1)
                                // Show bet for single hand only if not in clearTable or if in clearTable and not changing bet
                                if game.state.phase != .clearTable || (game.state.phase == .clearTable && !game.isChangingBet) {
                                    Text("Bet: $\(game.state.phase == .clearTable ? game.state.initialBet : bet)")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(height: 30)
                                }
                            }
                            .zIndex(1)
                        }
                    }
                    .frame(height: game.state.playerHands.count == 1 ? 256 : 256)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, -120)
        }
    }
}
