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
    float turn = atan2(-local.x, local.y) / 6.2831853;
    turn = turn < 0.0 ? turn + 1.0 : turn;
    if (turn > progress) { discard_fragment(); }
    """

    static let prototype: SCNNode? = {
        guard let url = Bundle.main.url(forResource: "jeton", withExtension: "usdz"),
              let scene = try? SCNScene(url: url),
              let node = scene.rootNode.childNode(withName: "Jeton", recursively: true) else { return nil }
        node.removeFromParentNode()
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
