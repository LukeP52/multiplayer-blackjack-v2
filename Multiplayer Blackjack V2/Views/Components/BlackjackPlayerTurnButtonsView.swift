import SwiftUI

struct BlackjackPlayerTurnButtonsView: View {
    let game: BlackjackGame
    let onDouble: () -> Void
    @State private var correctActionToFlash: BasicStrategyAction? = nil
    @State private var highlightTimer: Timer? = nil
    
    private func clearHighlight() {
        highlightTimer?.invalidate()
        highlightTimer = nil
        correctActionToFlash = nil
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Action buttons in their original position
                HStack(spacing: 8) {
                    if game.canSplit() {
                        ActionButton(title: "Split", color: .richRed, action: {
                            clearHighlight()
                            game.split()
                        }, isFlashing: correctActionToFlash == .split)
                    }
                    
                    if game.canDoubleDown() {
                        ActionButton(title: "Double", color: .silver, action: {
                            clearHighlight()
                            game.doubleDown()
                            onDouble()
                        }, isFlashing: correctActionToFlash == .double)
                    }
                    
                    if game.canStand() {
                        ActionButton(title: "Stand", color: .gold, action: {
                            clearHighlight()
                            game.stand()
                        }, isFlashing: correctActionToFlash == .stand)
                    }
                    
                    if game.canHit() {
                        ActionButton(title: "Hit", color: .richBlack, action: {
                            clearHighlight()
                            game.hit()
                        }, isFlashing: correctActionToFlash == .hit)
                    }
                }
                .frame(maxWidth: min(geometry.size.width * 0.9, 400))
                .frame(maxWidth: .infinity, alignment: .center)
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.75)
                .animation(nil, value: game.canSplit())
                .animation(nil, value: game.canDoubleDown())
                .animation(nil, value: game.canStand())
                .animation(nil, value: game.canHit())
                
                // Question mark button positioned below the action buttons
                if game.canHit() || game.canStand() || game.canDoubleDown() || game.canSplit() {
                    Button(action: {
                        if let dealerUpcard = game.state.dealerHand.first {
                            // For split hands, we need to handle both the first hand and subsequent hands
                            let playerHand = game.state.playerHands[game.state.activeHandIndex]
                            let correctAction = BasicStrategy.action(
                                for: playerHand,
                                dealerUpcard: dealerUpcard,
                                canDouble: game.canDoubleDown()
                            )
                            correctActionToFlash = correctAction
                            
                            // Set up timer to clear after 2 seconds
                            highlightTimer?.invalidate()
                            highlightTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                                clearHighlight()
                            }
                        }
                    }) {
                        Text("?")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                            .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.75 + 60)
                }
            }
        }
    }
    
    private struct ActionButton: View {
        let title: String
        let color: Color
        let action: () -> Void
        let isFlashing: Bool
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 1, x: 0, y: 0)
                    .frame(width: 90, height: 50)
                    .background(
                        ZStack {
                            color
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .white.opacity(0.4),
                                    .white.opacity(0.1),
                                    .clear,
                                    .black.opacity(0.1)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                    )
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.yellow, lineWidth: isFlashing ? 5 : 0)
                            .animation(.easeInOut(duration: 0.2), value: isFlashing)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
}

struct BlackjackPlayerTurnButtonsView_Previews: PreviewProvider {
    static var previews: some View {
        BlackjackPlayerTurnButtonsView(game: BlackjackGame(), onDouble: {})
    }
} 