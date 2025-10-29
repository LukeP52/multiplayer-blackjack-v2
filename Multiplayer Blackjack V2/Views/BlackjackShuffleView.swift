import SwiftUI

struct BlackjackShuffleView: View {
    @ObservedObject var game: BlackjackGame
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Background with blur
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Shuffle animation
                ZStack {
                    ForEach(0..<4) { index in
                        Image("card_back")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 180)
                            .rotationEffect(.degrees(Double(index) * 90))
                            .offset(x: CGFloat(index - 1) * 30)
                            .opacity(0.8)
                    }
                }
                .frame(height: 200)
                
                // Shuffle text
                Text("Reshuffling Deck...")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .padding(16)
                    .background(
                        Color.black
                            .opacity(0.5)
                            .blur(radius: 25)
                    )
                    .shadow(color: .black.opacity(0.95), radius: 15, x: 0, y: 8)
            }
        }
        .transition(.opacity)
    }
} 