import SwiftUI

struct ChipView: View {
    let value: Int
    let isSelected: Bool
    let isAllIn: Bool
    let action: () -> Void
    
    init(value: Int, isSelected: Bool, isAllIn: Bool = false, action: @escaping () -> Void) {
        self.value = value
        self.isSelected = isSelected
        self.isAllIn = isAllIn
        self.action = action
    }
    
    private var chipImageName: String {
        return "blackandgoldchip"
    }
    
    private var formattedChipValue: String {
        if value >= 1000 {
            if value % 1000 == 0 {
                return "\(value / 1000)K"
            } else {
                let thousands = value / 1000
                let hundreds = (value % 1000) / 100
                return hundreds > 0 ? "\(thousands).\(hundreds)K" : "\(thousands)K"
            }
        } else {
            return "\(value)"
        }
    }
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            ZStack {
                Image(chipImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 75, height: 75)
                    .scaleEffect(1.4)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                    .frame(width: 75, height: 75, alignment: .center)
                
                VStack(spacing: 1) {
                    if isAllIn {
                        Text("All In")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 1)
                    } else {
                        Text(formattedChipValue)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 1)
                    }
                }
            }
        }
        .accessibilityLabel("Bet \(value) chips")
    }
}

struct ScrollableChipView: View {
    @Binding var selectedChipValue: Int
    let playerBalance: Int
    let onChipSelected: (Int) -> Void
    
    private let baseChipValues = [10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000]
    
    private var availableChipValues: [Int] {
        let maxChipValue = playerBalance / 10
        let closestMaxChip = baseChipValues
            .filter { $0 <= maxChipValue }
            .max() ?? 1000
        return baseChipValues
            .filter { $0 <= closestMaxChip }
            .sorted(by: <)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        Color.clear.frame(width: 40)
                        ChipView(
                            value: playerBalance,
                            isSelected: selectedChipValue == playerBalance,
                            isAllIn: true,
                            action: {
                                let remainingBalance = playerBalance - selectedChipValue
                                if remainingBalance > 0 {
                                    onChipSelected(remainingBalance)
                                }
                            }
                        )
                        .id("allIn")
                        
                        ForEach(availableChipValues, id: \.self) { value in
                            ChipView(
                                value: value,
                                isSelected: selectedChipValue == value,
                                action: {
                                    selectedChipValue = value
                                    onChipSelected(value)
                                }
                            )
                            .id(value)
                        }
                        Color.clear.frame(width: 60).id("endSpacer")
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 85)
                .ignoresSafeArea(.container, edges: .horizontal)
                .onAppear {
                    proxy.scrollTo("endSpacer", anchor: .trailing)
                }
            }
            
            // White triangle indicator
            Image(systemName: "arrowtriangle.left.fill")
                .resizable()
                .frame(width: 12, height: 12)
                .foregroundColor(.white)
                .offset(x: 30, y: -15)
        }
        .frame(height: 85)
    }
}

struct ChipView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChipView(value: 100, isSelected: false) {}
            ScrollableChipView(selectedChipValue: .constant(100), playerBalance: 1000) { _ in }
        }
    }
}
