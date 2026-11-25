import SceneKit
import CoreMotion
import CoreImage

@MainActor
final class TokenRig {
    let scene: SCNScene
    let camera = SCNNode()
    private let tilt = SCNNode()
    private let jeton: SCNNode
    private let parens: [(node: SCNNode, rest: SCNVector3, side: Float)]
    private let jewels: [SCNNode]
    private let filet: SCNNode?
    private let dial: SCNNode?
    private let motion = CMMotionManager()
    private var face: PassToken.Face?
    private var stock = -1

    private static let spreadDistance: Float = 0.055
    private static let swayKey = "sway"
    private static let spinKey = "spin"

    init() {
        scene = SCNScene()
        scene.background.contents = UIColor.clear
        scene.lightingEnvironment.contents = TokenModel.environment()
        scene.lightingEnvironment.intensity = 2.2

        let model = TokenModel.load()
        jeton = model
        tilt.addChildNode(model)
        scene.rootNode.addChildNode(tilt)

        parens = [("ParenL", Float(-1)), ("ParenR", Float(1))].compactMap { name, side in
            guard let node = model.childNode(withName: name, recursively: true) else { return nil }
            return (node, node.position, side)
        }
        jewels = ["Index1", "Index2"].compactMap { model.childNode(withName: $0, recursively: true) }
        filet = model.childNode(withName: "Filet", recursively: true)
        dial = model.childNode(withName: "Cadran", recursively: true)
        filet?.geometry?.materials.forEach { $0.shaderModifiers = [.fragment: TokenModel.sweep] }

        let lens = SCNCamera()
        lens.fieldOfView = 17
        lens.zNear = 0.1
        lens.zFar = 20
        lens.wantsHDR = true
        lens.wantsExposureAdaptation = false
        lens.exposureOffset = 0
        lens.bloomIntensity = 0.15
        lens.bloomThreshold = 0.9
        lens.bloomBlurRadius = 6
        camera.camera = lens
        camera.position = SCNVector3(0, 0, 3.75)
        scene.rootNode.addChildNode(camera)
    }

    func start(reduceMotion: Bool) {
        guard !reduceMotion else { return }
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1 / 60
            motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
                guard let data else { return }
                let pitch = Float(data.attitude.pitch)
                let roll = Float(data.attitude.roll)
                MainActor.assumeIsolated { self?.lean(pitch: pitch, roll: roll) }
            }
        } else {
            tilt.runAction(TokenRig.sway(), forKey: TokenRig.swayKey)
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        tilt.removeAllActions()
    }

    func apply(face newFace: PassToken.Face, stock newStock: Int, animated: Bool, reduceMotion: Bool) {
        let previous = face
        guard previous != newFace || stock != newStock else { return }
        face = newFace
        stock = newStock

        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? duration(from: previous, to: newFace) : 0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: animated && isAirlock(newFace) ? .linear : .easeInEaseOut)
        for paren in parens {
            var position = paren.rest
            position.x += paren.side * TokenRig.spreadDistance * Float(spread(newFace))
            paren.node.position = position
        }
        for (index, jewel) in jewels.enumerated() {
            TokenModel.light(jewel, lit: newStock > index)
        }
        filet?.geometry?.materials.forEach { $0.setValue(NSNumber(value: progress(newFace)), forKey: "progress") }
        SCNTransaction.commit()

        jeton.filters = newFace == .spent ? [TokenModel.tarnish()] : nil
        spin(for: newFace, reduceMotion: reduceMotion)

        if animated, case .airlock = previous, case .open = newFace {
            celebrate(reduceMotion: reduceMotion)
        }
    }

    private func lean(pitch: Float, roll: Float) {
        let limit: Float = 0.22
        tilt.eulerAngles = SCNVector3(
            max(-limit, min(limit, (pitch - 0.7) * 0.35)),
            max(-limit, min(limit, roll * 0.35)),
            0
        )
    }

    private func spin(for face: PassToken.Face, reduceMotion: Bool) {
        guard let dial, !reduceMotion else { return }
        guard case .airlock(let progress) = face else {
            dial.removeAction(forKey: TokenRig.spinKey)
            dial.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.6, usesShortestUnitArc: true))
            return
        }
        if dial.action(forKey: TokenRig.spinKey) == nil {
            dial.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: -.pi * 2, duration: 4)), forKey: TokenRig.spinKey)
        }
        dial.action(forKey: TokenRig.spinKey)?.speed = 0.15 + 2.4 * progress * progress
    }

    private func celebrate(reduceMotion: Bool) {
        if let lens = camera.camera {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.18
            lens.bloomIntensity = 1.6
            lens.exposureOffset = 0.6
            SCNTransaction.completionBlock = {
                MainActor.assumeIsolated {
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.9
                    lens.bloomIntensity = 0.15
                    lens.exposureOffset = 0
                    SCNTransaction.commit()
                }
            }
            SCNTransaction.commit()
        }
        guard !reduceMotion else { return }
        let turn = SCNAction.rotateBy(x: 0, y: .pi * 2 + 0.34, z: 0, duration: 0.7)
        turn.timingMode = .easeInEaseOut
        let back = SCNAction.rotateBy(x: 0, y: -0.46, z: 0, duration: 0.28)
        back.timingMode = .easeInEaseOut
        let settle = SCNAction.rotateBy(x: 0, y: 0.12, z: 0, duration: 0.22)
        settle.timingMode = .easeOut
        let lift = SCNAction.sequence([
            .moveBy(x: 0, y: 0, z: 0.35, duration: 0.35),
            .moveBy(x: 0, y: 0, z: -0.35, duration: 0.6),
        ])
        lift.timingMode = .easeInEaseOut
        jeton.runAction(.group([.sequence([turn, back, settle]), lift]))
    }

    private func duration(from old: PassToken.Face?, to new: PassToken.Face) -> CFTimeInterval {
        if case .airlock = old, case .airlock = new { return 1 }
        if case .open = old, case .open = new { return 1 }
        return 0.6
    }

    private func isAirlock(_ face: PassToken.Face) -> Bool {
        if case .airlock = face { return true }
        return false
    }

    private func spread(_ face: PassToken.Face) -> Double {
        switch face {
        case .rest, .spent: 0
        case .airlock(let progress): 0.7 * progress
        case .open: 1
        }
    }

    private func progress(_ face: PassToken.Face) -> Double {
        switch face {
        case .rest, .spent: 0
        case .airlock(let progress): progress
        case .open(let left): left
        }
    }

    private static func sway() -> SCNAction {
        let period: CGFloat = 9
        return .repeatForever(.customAction(duration: period) { node, elapsed in
            let phase = Float(elapsed / period) * .pi * 2
            node.eulerAngles = SCNVector3(0.07 * sin(phase), 0.12 * sin(phase * 2 + 0.6), 0)
        })
    }
}
