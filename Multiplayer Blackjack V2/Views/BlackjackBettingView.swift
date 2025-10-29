import SwiftUI

struct BlackjackBettingView: View {
    @ObservedObject var game: BlackjackGame
    @Binding var isPlaceBetDisabled: Bool

    var body: some View {
        GeometryReader { geometry in
            VStack {
                // Chips
                ScrollableChipView(
                    selectedChipValue: Binding(
                        get: { game.state.currentBet },
                        set: { _ in }
                    ),
                    playerBalance: game.state.playerBalance,
                    onChipSelected: { value in
                        game.addToBet(amount: value)
                    }
                )
                .frame(maxWidth: .infinity)

                // Bet amount
                Text("Bet: $\(game.state.currentBet)")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .frame(height: 30)

                // Action buttons
                HStack(spacing: 15) {
                    Button(action: {
                        game.clearBet()
                    }) {
                        Text("Clear")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 1, x: 0, y: 0)
                            .frame(width: 128, height: 55)
                            .background(
                                ZStack {
                                    Color.gold
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
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .disabled(game.state.currentBet == 0)
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button(action: {
                        isPlaceBetDisabled = true
                        game.confirmBet()
                    }) {
                        Text("Place Bet")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 1, x: 0, y: 0)
                            .frame(width: 128, height: 55)
                            .background(
                                ZStack {
                                    Color.richBlack
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
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .disabled(isPlaceBetDisabled || !game.isBetValid)
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
} 