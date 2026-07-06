import AVFoundation

final class SoundPlayer {
    static let shared = SoundPlayer()
    private var players: [String: AVAudioPlayer] = [:]

    func play(_ name: String, volume: Float) {
        guard let url = Bundle.resources.url(forResource: name, withExtension: "m4a"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = volume
        players[name] = player
        player.play()
    }

    func stop(_ name: String) {
        players[name]?.stop()
        players[name] = nil
    }
}
