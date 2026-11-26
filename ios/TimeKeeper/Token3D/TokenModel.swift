import SceneKit
import UIKit
import CoreImage

@MainActor
enum TokenModel {
    static let sweep = """
    #pragma arguments
    float lower;
    float upper;
    #pragma body
    float3 local = (scn_node.inverseModelViewTransform * float4(_surface.position, 1.0)).xyz;
    float turn = atan2(-local.x, local.y) / 6.2831853;
    turn = turn < 0.0 ? turn + 1.0 : turn;
    if (turn < lower || turn > upper) { discard_fragment(); }
    """

    private static func grade(tint: SIMD3<Double>, roughness: Double) -> String {
        """
        float3 base = _surface.diffuse.rgb;
        float grey = dot(base, float3(0.2126, 0.7152, 0.0722));
        _surface.diffuse.rgb = mix(float3(grey), base, 0.8) * float3(\(tint.x), \(tint.y), \(tint.z));
        _surface.roughness = clamp(_surface.roughness + \(roughness), 0.0, 1.0);
        """
    }

    private static let steel = grade(tint: [0.30, 0.40, 0.52], roughness: 0)
    private static let brass = grade(tint: [0.93, 0.95, 1.12], roughness: 0.07)

    static let prototype: SCNNode? = {
        guard let url = Bundle.main.url(forResource: "jeton", withExtension: "usdz"),
              let scene = try? SCNScene(url: url),
              let node = scene.rootNode.childNode(withName: "Jeton", recursively: true) else { return nil }
        node.removeFromParentNode()
        var graded = Set<ObjectIdentifier>()
        node.enumerateHierarchy { child, _ in
            child.castsShadow = false
            for material in child.geometry?.materials ?? [] where graded.insert(ObjectIdentifier(material)).inserted {
                switch material.name {
                case "AcierGuilloche", "AcierBrosse", "AcierPoli":
                    material.shaderModifiers = [.surface: steel]
                    if material.name == "AcierGuilloche" { material.normal.intensity = 1.6 }
                case "Laiton", "LaitonPoli", "LaitonFilet":
                    material.shaderModifiers = [.surface: brass]
                default:
                    break
                }
            }
        }
        return node
    }()

    static let environment: URL? = Bundle.main.url(forResource: "env", withExtension: "hdr")
        ?? Bundle.main.url(forResource: "env", withExtension: "png")

    static func instance() -> SCNNode? {
        guard let prototype else { return nil }
        let node = prototype.clone()
        for name in ["Index1", "Index2", "Filet", "Verre"] {
            guard let mesh = mesh(name, in: node), let geometry = mesh.geometry?.copy() as? SCNGeometry else { continue }
            geometry.materials = geometry.materials.compactMap { $0.copy() as? SCNMaterial }
            mesh.geometry = geometry
        }
        if let glass = mesh("Verre", in: node)?.geometry?.firstMaterial {
            glass.diffuse.contents = UIColor(white: 1, alpha: 0.02)
            glass.transparent.contents = nil
            glass.transparency = 1
            glass.transparencyMode = .dualLayer
            glass.blendMode = .add
            glass.writesToDepthBuffer = false
        }
        return node
    }

    static func hand() -> SCNNode {
        let polished = SCNMaterial()
        polished.lightingModel = .physicallyBased
        polished.diffuse.contents = UIColor(red: 0xD4 / 255, green: 0xA8 / 255, blue: 0x62 / 255, alpha: 1)
        polished.metalness.contents = 1.0
        polished.roughness.contents = 0.3

        let blade = UIBezierPath()
        blade.move(to: CGPoint(x: -12, y: 0))
        blade.addLine(to: CGPoint(x: -2, y: 392))
        blade.addCurve(to: CGPoint(x: 2, y: 392), controlPoint1: CGPoint(x: -1, y: 402), controlPoint2: CGPoint(x: 1, y: 402))
        blade.addLine(to: CGPoint(x: 12, y: 0))
        blade.addLine(to: CGPoint(x: 6, y: -78))
        blade.addLine(to: CGPoint(x: 0, y: -128))
        blade.addLine(to: CGPoint(x: -6, y: -78))
        blade.close()

        let weight = UIBezierPath(ovalIn: CGRect(x: -19, y: -114, width: 38, height: 38))
        weight.append(UIBezierPath(ovalIn: CGRect(x: -10, y: -105, width: 20, height: 20)).reversing())

        let node = SCNNode()
        for path in [blade, weight] {
            path.flatness = 0.3
            let shape = SCNShape(path: path, extrusionDepth: 2.2)
            shape.chamferRadius = 0.8
            shape.materials = [polished]
            let part = SCNNode(geometry: shape)
            part.scale = SCNVector3(0.001, 0.001, 0.001)
            part.position.z = -0.0545
            node.addChildNode(part)
        }

        let canon = SCNCylinder(radius: 0.019, height: 0.0075)
        canon.radialSegmentCount = 64
        canon.materials = [polished]
        let canonNode = SCNNode(geometry: canon)
        canonNode.eulerAngles.x = .pi / 2
        canonNode.position.z = -0.0528
        node.addChildNode(canonNode)

        let blued = SCNMaterial()
        blued.lightingModel = .physicallyBased
        blued.diffuse.contents = UIColor(red: 0x1F / 255, green: 0x3A / 255, blue: 0x8A / 255, alpha: 1)
        blued.metalness.contents = 1.0
        blued.roughness.contents = 0.08
        let cap = SCNSphere(radius: 0.009)
        cap.segmentCount = 48
        cap.materials = [blued]
        let capNode = SCNNode(geometry: cap)
        capNode.scale = SCNVector3(1, 1, 0.5)
        capNode.position.z = -0.0566
        node.addChildNode(capNode)
        return node
    }

    static func mesh(_ name: String, in node: SCNNode) -> SCNNode? {
        node.childNodes { child, _ in child.name == name && child.geometry != nil }.first
    }

    static func tarnish() -> CIFilter {
        let filter = CIFilter(name: "CIColorControls") ?? CIFilter()
        filter.setValue(0.05, forKey: kCIInputSaturationKey)
        filter.setValue(-0.04, forKey: kCIInputBrightnessKey)
        filter.setValue(0.92, forKey: kCIInputContrastKey)
        return filter
    }
}
