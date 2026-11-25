import SwiftUI
import SceneKit

struct TokenScene: UIViewRepresentable {
    let face: PassToken.Face
    let stock: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> TokenRig {
        TokenRig()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = true
        view.isPlaying = true
        view.allowsCameraControl = false
        view.isUserInteractionEnabled = false
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.camera
        context.coordinator.start(reduceMotion: reduceMotion)
        context.coordinator.apply(face: face, stock: stock, animated: false, reduceMotion: reduceMotion)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.apply(face: face, stock: stock, animated: true, reduceMotion: reduceMotion)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: TokenRig) {
        coordinator.stop()
    }
}
