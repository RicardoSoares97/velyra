import AVFoundation
import SwiftUI
import UIKit

final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        guard let layer = layer as? AVPlayerLayer else {
            preconditionFailure("PlayerLayerView requires AVPlayerLayer")
        }
        return layer
    }
}

struct LoopingVideoView: UIViewRepresentable {
    let url: URL

    final class Coordinator {
        let player = AVQueuePlayer()
        var looper: AVPlayerLooper?

        init(url: URL) {
            player.isMuted = true
            player.actionAtItemEnd = .none
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            player.play()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = context.coordinator.player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        if context.coordinator.player.timeControlStatus != .playing {
            context.coordinator.player.play()
        }
    }

    static func dismantleUIView(_ uiView: PlayerLayerView, coordinator: Coordinator) {
        coordinator.player.pause()
        coordinator.looper?.disableLooping()
        uiView.playerLayer.player = nil
    }
}
