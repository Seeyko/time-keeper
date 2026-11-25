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
    private let jewels: [(mesh: SCNNode, tint: Any?, glow: Any?)]
    private let filet: SCNNode?
    private let medallion: SCNNode?
    private let motion = CMMotionManager()
    private var face: PassToken.Face?
    private var stock = -1
    private var turning = false

    private static let spreadDistance: Float = 0.036
    private static let spinKey = "spin"
    private static let unlit = UIColor(red: 0x2B / 255, green: 0x26 / 255, blue: 0x20 / 255, alpha: 1)

    init() {
        scene = SCNScene()
        scene.background.contents = UIColor.clear
        scene.lightingEnvironment.contents = TokenModel.environment
        scene.lightingEnvironment.intensity = 1.15

        let model = TokenModel.instance() ?? SCNNode()
        jeton = model
        tilt.addChildNode(model)
        scene.rootNode.addChildNode(tilt)

        parens = [("ParenL", Float(-1)), ("ParenR", Float(1))].compactMap { name, side in
            guard let node = model.childNode(withName: name, recursively: true) else { return nil }
            return (node, node.position, side)
        }
        jewels = ["Index1", "Index2"].compactMap { name in
            guard let mesh = TokenModel.mesh(name, in: model), let material = mesh.geometry?.firstMaterial else { return nil }
            return (mesh, material.diffuse.contents, material.emission.contents)
        }
        filet = TokenModel.mesh("Filet", in: model)
        medallion = model.childNode(withName: "Medaillon", recursively: true)
        filet?.geometry?.materials.forEach { $0.shaderModifiers = [.fragment: TokenModel.sweep] }

        let lens = SCNCamera()
        lens.fieldOfView = 17
        lens.zNear = 0.1
        lens.zFar = 20
        lens.wantsHDR = true
        lens.wantsExposureAdaptation = false
        lens.exposureOffset = 0
        lens.bloomIntensity = 0.12
        lens.bloomThreshold = 0.92
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
            tilt.runAction(TokenRig.sway())
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
        let flipping = animated && !reduceMotion && isAirlock(previous) && isOpen(newFace)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? duration(from: previous, to: newFace) : 0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: animated && isAirlock(newFace) ? .linear : .easeInEaseOut)
        for paren in parens {
            var position = paren.rest
            position.x += paren.side * TokenRig.spreadDistance * Float(spread(newFace))
            paren.node.position = position
        }
        for (index, jewel) in jewels.enumerated() {
            let lit = newStock > index && newFace != .spent
            jewel.mesh.geometry?.firstMaterial?.diffuse.contents = lit ? jewel.tint : TokenRig.unlit
            jewel.mesh.geometry?.firstMaterial?.emission.contents = lit ? jewel.glow : UIColor.black
        }
        filet?.geometry?.materials.forEach { $0.setValue(NSNumber(value: progress(newFace)), forKey: "progress") }
        if !flipping && !turning {
            jeton.eulerAngles.y = isOpen(newFace) ? .pi : 0
        }
        SCNTransaction.commit()

        jeton.filters = newFace == .spent ? [TokenModel.tarnish()] : nil
        spin(for: newFace, reduceMotion: reduceMotion)

        if animated && isAirlock(previous) && isOpen(newFace) {
            celebrate(flip: flipping)
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
        guard let medallion, !reduceMotion else { return }
        guard case .airlock(let progress) = face else {
            medallion.removeAction(forKey: TokenRig.spinKey)
            medallion.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.6, usesShortestUnitArc: true))
            return
        }
        if medallion.action(forKey: TokenRig.spinKey) == nil {
            medallion.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: -.pi * 2, duration: 4)), forKey: TokenRig.spinKey)
        }
        medallion.action(forKey: TokenRig.spinKey)?.speed = 0.15 + 2.4 * progress * progress
    }

    private func celebrate(flip: Bool) {
        if let lens = camera.camera {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.18
            lens.bloomIntensity = 1.4
            lens.exposureOffset = 0.5
            SCNTransaction.completionBlock = { [weak self] in
                Task { @MainActor in self?.dim() }
            }
            SCNTransaction.commit()
        }
        guard flip else { return }
        turning = true
        let spin = SCNAction.rotateBy(x: 0, y: .pi * 5 + 0.42, z: 0, duration: 1.25)
        spin.timingMode = .easeIn
        let back = SCNAction.rotateBy(x: 0, y: -0.62, z: 0, duration: 0.32)
        back.timingMode = .easeInEaseOut
        let again = SCNAction.rotateBy(x: 0, y: 0.28, z: 0, duration: 0.26)
        again.timingMode = .easeInEaseOut
        let settle = SCNAction.rotateBy(x: 0, y: -0.08, z: 0, duration: 0.22)
        settle.timingMode = .easeOut
        let lift = SCNAction.sequence([
            .moveBy(x: 0, y: 0, z: 0.4, duration: 0.6),
            .moveBy(x: 0, y: 0, z: -0.4, duration: 0.9),
        ])
        lift.timingMode = .easeInEaseOut
        jeton.runAction(.group([.sequence([spin, back, again, settle]), lift])) { [weak self] in
            Task { @MainActor in self?.landed() }
        }
    }

    private func dim() {
        guard let lens = camera.camera else { return }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.9
        lens.bloomIntensity = 0.12
        lens.exposureOffset = 0
        SCNTransaction.commit()
    }

    private func landed() {
        turning = false
        jeton.eulerAngles.y = isOpen(face) ? .pi : 0
    }

    private func duration(from old: PassToken.Face?, to new: PassToken.Face) -> CFTimeInterval {
        if isAirlock(old) && isAirlock(new) { return 1 }
        if isOpen(old) && isOpen(new) { return 1 }
        return 0.6
    }

    private func isAirlock(_ face: PassToken.Face?) -> Bool {
        if case .airlock = face { return true }
        return false
    }

    private func isOpen(_ face: PassToken.Face?) -> Bool {
        if case .open = face { return true }
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
