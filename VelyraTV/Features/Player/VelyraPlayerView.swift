import AVKit
import SwiftUI

struct VelyraPlayerView: View {
    let url: URL

    @State private var player: AVPlayer

    init(url: URL) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea()
            .onAppear {
                player.play()
            }
            .onDisappear {
                player.pause()
            }
    }
}
