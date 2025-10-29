import SwiftUI

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 25) {
                    Text("Game Rules")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                    
                    Group {
                        InfoSection(title: "Deck", content: "The game uses 4 standard decks of 52 cards.")
                        InfoSection(title: "Basic Rules", content: "Get closer to 21 than the dealer without going over. Face cards are worth 10, Aces are worth 1 or 11.")
                        InfoSection(title: "Splitting", content: "You can split pairs into two separate hands. After splitting Aces, each hand receives only one additional card. A hand can only be split once.")
                        InfoSection(title: "Doubling Down", content: "You can double your bet after receiving your first two cards. You'll receive exactly one more card.")
                        InfoSection(title: "Dealer Rules", content: "Dealer must hit on 16 and below, stand on 17 and above.")
                        InfoSection(title: "Blackjack Payout", content: "Blackjack pays 3:2 (1.5x your bet).")
                        InfoSection(title: "Insurance", content: "When dealer shows an Ace, you can take insurance against dealer blackjack.")
                        InfoSection(title: "Bonus Bar", content: "The yellow progress bar at the bottom of the screen tracks your progress. After playing 50 hands, you'll receive a $25,000 bonus to your bankroll.")
                        InfoSection(title: "Basic Strategy", content: "The question mark button at the bottom of the screen will highlight the correct play according to Blackjack Basic Strategy. This strategy is mathematically proven to give you the best odds of winning. Following it will help you make optimal decisions in every situation.")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            
            // Back Button
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

struct InfoSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(content)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(.horizontal, 5)
    }
}

#Preview {
    InfoView()
} 