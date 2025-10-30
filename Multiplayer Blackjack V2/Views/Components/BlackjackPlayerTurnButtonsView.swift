import SwiftUI

struct BlackjackPlayerTurnButtonsView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
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
                let screenType: ScreenType = {
                    if horizontalSizeClass == .compact {
                        return .phone
                    } else if geometry.size.width < 900 {
                        return .miniTablet
                    } else {
                        return .tablet
                    }
                }()
                HStack(spacing: {
                    switch screenType {
                    case .phone: return 8
                    case .miniTablet: return 15
                    case .tablet: return 25
                    }
                }()) {
                    if game.canSplit() {
                        ActionButton(title: "Split", color: .richRed, action: {
                            clearHighlight()
                            game.split()
                        }, isFlashing: correctActionToFlash == .split, screenType: screenType)
                    }
                    
                    if game.canDoubleDown() {
                        ActionButton(title: "Double", color: .silver, action: {
                            clearHighlight()
                            game.doubleDown()
                            onDouble()
                        }, isFlashing: correctActionToFlash == .double, screenType: screenType)
                    }
                    
                    if game.canStand() {
                        ActionButton(title: "Stand", color: .gold, action: {
                            clearHighlight()
                            game.stand()
                        }, isFlashing: correctActionToFlash == .stand, screenType: screenType)
                    }
                    
                    if game.canHit() {
                        ActionButton(title: "Hit", color: .richBlack, action: {
                            clearHighlight()
                            game.hit()
                        }, isFlashing: correctActionToFlash == .hit, screenType: screenType)
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
                            .font(.system(size: {
                                switch screenType {
                                case .phone: return 24
                                case .miniTablet: return 28
                                case .tablet: return 32
                                }
                            }(), weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: {
                                switch screenType {
                                case .phone: return 40
                                case .miniTablet: return 50
                                case .tablet: return 60
                                }
                            }(), height: {
                                switch screenType {
                                case .phone: return 40
                                case .miniTablet: return 50
                                case .tablet: return 60
                                }
                            }())
                            .background(Circle().fill(Color.white.opacity(0.2)))
                            .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.75 + {
                        switch screenType {
                        case .phone: return 60
                        case .miniTablet: return 75
                        case .tablet: return 90
                        }
                    }())
                }
            }
        }
    }
    
    private struct ActionButton: View {
        let title: String
        let color: Color
        let action: () -> Void
        let isFlashing: Bool
        let screenType: ScreenType
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: {
                        switch screenType {
                        case .phone: return 24
                        case .miniTablet: return 28
                        case .tablet: return 32
                        }
                    }(), weight: .heavy))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 1, x: 0, y: 0)
                    .frame(width: {
                        switch screenType {
                        case .phone: return 90
                        case .miniTablet: return 105
                        case .tablet: return 130
                        }
                    }(), height: {
                        switch screenType {
                        case .phone: return 50
                        case .miniTablet: return 65
                        case .tablet: return 80
                        }
                    }())
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