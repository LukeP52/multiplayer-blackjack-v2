import SwiftUI

struct BlackjackNotificationView: View {
    let playerHands: [[Card]]
    let handNotifications: [Int: String]
    @Binding var handNotificationOpacities: [Int: Double]
    let flippedCardCounts: [Int: Int]
    @Binding var showResolutionButtons: Bool
    let game: BlackjackGame
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            ForEach(playerHands.indices, id: \.self) { handIndex in
                if let notification = handNotifications[handIndex], !notification.isEmpty {
                    NotificationText(
                        text: notification,
                        opacity: handNotificationOpacities[handIndex] ?? 0.0,
                        xOffset: playerHands.count > 1 ? (handIndex == 0 ? geometry.size.width * 0.15 : -geometry.size.width * 0.15) : 0,
                        yOffset: 0
                    )
                    .onAppear {
                        animateNotification(for: handIndex)
                    }
                }
            }
            
            if let bonusText = game.bonusNotification {
                NotificationText(
                    text: bonusText,
                    opacity: handNotificationOpacities.values.first ?? 0.0,
                    xOffset: 0,
                    yOffset: -geometry.size.height * 0.2,
                    isBonus: true
                )
            }
        }
    }
    
    private func animateNotification(for index: Int) {
        let isBust = handNotifications[index]?.contains("Bust") ?? false
        let delay = isBust ? 0.3 : 0.25
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
            
            withAnimation(.easeInOut(duration: 0.5)) {
                handNotificationOpacities[index] = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    handNotificationOpacities[index] = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    handNotificationOpacities.removeValue(forKey: index)
                    if handNotificationOpacities.isEmpty {
                        // No action needed
                    }
                }
            }
        }
    }
}

private struct NotificationText: View {
    let text: String
    let opacity: Double
    let xOffset: CGFloat
    let yOffset: CGFloat
    var isBonus: Bool = false
    
    private var isPositive: Bool {
        text.contains("Won") || (text.contains("Blackjack") && !text.contains("Dealer"))
    }
    
    private var isNegative: Bool {
        text.contains("Lost") || text.contains("Bust") || text.contains("Dealer Blackjack")
    }
    
    private var splitText: (String, String) {
        if let range = text.range(of: "\n") {
            let firstPart = String(text[..<range.lowerBound])
            let secondPart = String(text[range.upperBound...])
            return (firstPart, secondPart)
        }
        return (text, "")
    }
    
    private func formatAmount(_ text: String) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        
        // Remove any $ or +/- symbols before parsing
        let cleanText = text.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: "-", with: "")
        
        if let number = Int(cleanText),
           let formattedNumber = numberFormatter.string(from: NSNumber(value: number)) {
            return formattedNumber
        }
        return text
    }
    
    var body: some View {
        let (title, amount) = splitText
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(isBonus ? .yellow : .white)
            
            if !amount.isEmpty {
                Text(formatAmount(amount))
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(isBonus ? .green : isPositive ? .green : isNegative ? .red : .white)
            }
        }
        .padding(16)
        .background(
            Color.black
                .opacity(0.5)
                .blur(radius: 25)
        )
        .shadow(color: .black.opacity(0.95), radius: 15, x: 0, y: 8)
        .opacity(opacity)
        .offset(x: xOffset, y: yOffset)
    }
}

struct BlackjackNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        GeometryReader { geometry in
            BlackjackNotificationView(
                playerHands: [[]],
                handNotifications: [:],
                handNotificationOpacities: .constant([:]),
                flippedCardCounts: [:],
                showResolutionButtons: .constant(false),
                game: BlackjackGame(),
                geometry: geometry
            )
        }
    }
} 