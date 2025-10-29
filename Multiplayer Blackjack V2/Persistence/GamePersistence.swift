import Foundation

class GamePersistence {
    private let stateKey = "gameState"
    
    func saveState(_ state: GameState) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(state) {
            UserDefaults.standard.set(encoded, forKey: stateKey)
        }
    }
    
    func loadState() -> GameState? {
        guard let data = UserDefaults.standard.data(forKey: stateKey) else {
            return nil
        }
        let decoder = JSONDecoder()
        if let state = try? decoder.decode(GameState.self, from: data) {
            return state
        } else {
            return nil
        }
    }
}
