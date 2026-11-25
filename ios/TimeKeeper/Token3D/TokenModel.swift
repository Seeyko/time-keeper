import SceneKit
import UIKit
import CoreImage

@MainActor
enum TokenModel {
    static let sweep = """
    #pragma arguments
    float progress;
    #pragma body
    float3 local = (scn_node.inverseModelViewTransform * float4(_surface.position, 1.0)).xyz;
    float turn = atan2(local.x, local.y) / 6.2831853;
    turn = turn < 0.0 ? turn + 1.0 : turn;
    if (turn > progress) { discard_fragment(); }
    """

    private static let dialTextures = TokenTextures.guilloche(side: 768)
    private static let brushTexture = TokenTextures.brushed(side: 512)

    static func load() -> SCNNode {
        if let url = Bundle.main.url(forResource: "jeton", withExtension: "usdz"),
           let scene = try? SCNScene(url: url),
           let node = scene.rootNode.childNode(withName: "Jeton", recursively: true) {
            node.removeFromParentNode()
            return node
        }
        return build()
    }

    static func environment() -> Any {
        if let url = Bundle.main.url(forResource: "env", withExtension: "png"), let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        let size = CGSize(width: 1024, height: 512)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor(white: 0.62, alpha: 1).cgColor,
                UIColor(white: 0.22, alpha: 1).cgColor,
                UIColor(red: 0.42, green: 0.34, blue: 0.24, alpha: 1).cgColor,
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.55, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            let boxes: [(CGRect, UIColor)] = [
                (CGRect(x: 330, y: 40, width: 380, height: 170), UIColor(white: 1, alpha: 1)),
                (CGRect(x: 90, y: 100, width: 110, height: 280), UIColor(white: 0.95, alpha: 1)),
                (CGRect(x: 800, y: 120, width: 90, height: 260), UIColor(red: 1, green: 0.88, blue: 0.66, alpha: 1)),
                (CGRect(x: 520, y: 290, width: 320, height: 60), UIColor(white: 0.7, alpha: 1)),
                (CGRect(x: 0, y: 0, width: 1024, height: 30), UIColor(white: 0.9, alpha: 1)),
            ]
            for (rect, color) in boxes {
                color.setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: 18).fill()
            }
        }
    }

    static func light(_ jewel: SCNNode, lit: Bool) {
        guard let material = jewel.geometry?.firstMaterial else { return }
        material.diffuse.contents = lit ? UIColor(red: 1, green: 0.93, blue: 0.74, alpha: 1) : UIColor(red: 0.14, green: 0.09, blue: 0.03, alpha: 1)
        material.emission.contents = lit ? UIColor(red: 1, green: 0.78, blue: 0.42, alpha: 1) : UIColor.black
    }

    static func tarnish() -> CIFilter {
        let filter = CIFilter(name: "CIColorControls") ?? CIFilter()
        filter.setValue(0.05, forKey: kCIInputSaturationKey)
        filter.setValue(-0.04, forKey: kCIInputBrightnessKey)
        filter.setValue(0.92, forKey: kCIInputContrastKey)
        return filter
    }

    private static func build() -> SCNNode {
        let jeton = SCNNode()
        jeton.name = "Jeton"

        let brass = metal(red: 0.96, green: 0.76, blue: 0.42, roughness: 0.2)
        brass.normal.contents = brushTexture
        brass.normal.intensity = 0.22
        let polished = metal(red: 1, green: 0.86, blue: 0.56, roughness: 0.08)

        let body = shape(disc(radius: 0.5), depth: 0.07, chamfer: 0.018)
        body.materials = [brass]
        jeton.addChildNode(named("Corps", body))

        let rim = shape(ring(outer: 0.5, inner: 0.415), depth: 0.1, chamfer: 0.014)
        rim.materials = [brass]
        jeton.addChildNode(named("Lunette", rim))

        let face = shape(disc(radius: 0.416), depth: 0.004, chamfer: 0)
        face.materials = [steel()]
        let dial = named("Cadran", face)
        dial.position.z = 0.037
        jeton.addChildNode(dial)

        let groove = shape(ring(outer: 0.384, inner: 0.366), depth: 0.002, chamfer: 0)
        let grooveMaterial = metal(red: 0.05, green: 0.08, blue: 0.2, roughness: 0.5)
        groove.materials = [grooveMaterial]
        let track = named("Piste", groove)
        track.position.z = 0.04
        jeton.addChildNode(track)

        let filetShape = shape(ring(outer: 0.383, inner: 0.367), depth: 0.004, chamfer: 0)
        let glow = SCNMaterial()
        glow.lightingModel = .constant
        glow.diffuse.contents = UIColor(red: 1, green: 0.88, blue: 0.6, alpha: 1)
        glow.emission.contents = UIColor(red: 1, green: 0.8, blue: 0.45, alpha: 1)
        filetShape.materials = [glow]
        let filet = named("Filet", filetShape)
        filet.position.z = 0.042
        jeton.addChildNode(filet)

        for side in [Float(-1), Float(1)] {
            let arc = shape(paren(side: CGFloat(side)), depth: 0.04, chamfer: 0.012)
            arc.materials = [polished]
            let node = named(side < 0 ? "ParenL" : "ParenR", arc)
            node.position = SCNVector3(side * 0.035, 0, 0.06)
            jeton.addChildNode(node)
        }

        for (index, angle) in [Float(13), Float(-13)].enumerated() {
            let stone = SCNSphere(radius: 0.024)
            stone.segmentCount = 32
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.metalness.contents = 0.0
            material.roughness.contents = 0.18
            stone.materials = [material]
            let node = named("Index\(index + 1)", stone)
            let radians = angle * .pi / 180
            node.position = SCNVector3(-sin(radians) * 0.458, cos(radians) * 0.458, 0.05)
            node.scale = SCNVector3(1, 1, 0.55)
            jeton.addChildNode(node)
        }

        let dome = SCNSphere(radius: 0.416)
        dome.segmentCount = 96
        let glass = SCNMaterial()
        glass.lightingModel = .physicallyBased
        glass.diffuse.contents = UIColor(white: 1, alpha: 0.02)
        glass.metalness.contents = 0.0
        glass.roughness.contents = 0.03
        glass.transparencyMode = .dualLayer
        glass.blendMode = .add
        glass.writesToDepthBuffer = false
        glass.fresnelExponent = 2.5
        dome.materials = [glass]
        let verre = named("Verre", dome)
        verre.position.z = 0.037
        verre.scale = SCNVector3(1, 1, 0.13)
        verre.renderingOrder = 10
        jeton.addChildNode(verre)

        return jeton
    }

    private static let scale: CGFloat = 100

    private static func shape(_ path: UIBezierPath, depth: CGFloat, chamfer: CGFloat) -> SCNShape {
        let scaled = path.copy() as? UIBezierPath ?? path
        scaled.apply(CGAffineTransform(scaleX: scale, y: scale))
        scaled.flatness = 0.15
        let made = SCNShape(path: scaled, extrusionDepth: depth * scale)
        made.chamferRadius = chamfer * scale
        return made
    }

    private static func named(_ name: String, _ geometry: SCNGeometry) -> SCNNode {
        let node = SCNNode(geometry: geometry)
        node.name = name
        if geometry is SCNShape {
            node.scale = SCNVector3(1 / Float(scale), 1 / Float(scale), 1 / Float(scale))
        }
        return node
    }

    private static func metal(red: CGFloat, green: CGFloat, blue: CGFloat, roughness: CGFloat) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIColor(red: red, green: green, blue: blue, alpha: 1)
        material.metalness.contents = 1.0
        material.roughness.contents = roughness
        return material
    }

    private static func steel() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        let textures = dialTextures
        material.diffuse.contents = textures.color
        material.normal.contents = textures.normal
        material.normal.intensity = 0.9
        material.metalness.contents = 0.55
        material.roughness.contents = 0.32

        return material
    }

    private static func disc(radius: CGFloat) -> UIBezierPath {
        let path = UIBezierPath(ovalIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        return path
    }

    private static func ring(outer: CGFloat, inner: CGFloat) -> UIBezierPath {
        let path = disc(radius: outer)
        path.append(disc(radius: inner).reversing())
        return path
    }

    private static func paren(side: CGFloat) -> UIBezierPath {
        let curve = UIBezierPath()
        let half: CGFloat = 0.15
        let reach: CGFloat = 0.06
        curve.move(to: CGPoint(x: 0, y: half))
        curve.addQuadCurve(to: CGPoint(x: 0, y: -half), controlPoint: CGPoint(x: side * reach * 2, y: 0))
        let stroked = curve.cgPath.copy(strokingWithWidth: 0.05, lineCap: .round, lineJoin: .round, miterLimit: 1)
        let path = UIBezierPath(cgPath: stroked)
        return path
    }
}
