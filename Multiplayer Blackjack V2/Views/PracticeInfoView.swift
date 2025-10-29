import SwiftUI

struct PracticeInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 25) {
                    Text("Practice Mode")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                    
                    Group {
                        InfoSection(title: "Goal", content: "Make 25 correct basic strategy decisions in a row to earn a $25,000 bonus to your bankroll.")
                        InfoSection(title: "Basic Strategy", content: "Each hand will present you with a decision after dealing. You must choose the action button that aligns with Blackjack Basic Strategy. Following this strategy gives you the best odds of winning.")
                        InfoSection(title: "Feedback", content: "After each decision, you'll receive immediate feedback. A correct choice increases your streak, while an incorrect choice resets it to zero.")
                        InfoSection(title: "Dealer Cards", content: "The dealer's hole card is revealed after you make your decision, helping you understand the full context of each hand.")
                        InfoSection(title: "Progress", content: "Your current streak is displayed at the bottom of the screen. Keep making correct decisions to reach the 25-hand goal.")
                        InfoSection(title: "Bonus", content: "Once you reach 25 correct decisions in a row, you'll receive a $25,000 bonus added directly to your bankroll.")
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

struct PracticeInfoView_Previews: PreviewProvider {
    static var previews: some View {
        PracticeInfoView()
    }
} 