import UIKit

enum TokenTextures {
    static func guilloche(side: Int) -> (color: UIImage, normal: UIImage) {
        let height = heightMap(side: side)
        return (color(side: side, height: height), normal(side: side, height: height))
    }

    static func brushed(side: Int) -> UIImage {
        var pixels = [UInt8](repeating: 128, count: side * side)
        var seed: UInt32 = 7
        let center = Float(side) / 2
        var rings = [Float](repeating: 0, count: side)
        for index in rings.indices {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            rings[index] = Float(seed >> 24) / 255
        }
        for y in 0..<side {
            for x in 0..<side {
                let dx = Float(x) - center
                let dy = Float(y) - center
                let r = min(side - 1, Int(sqrt(dx * dx + dy * dy) * 2))
                pixels[y * side + x] = UInt8(96 + rings[r] * 64)
            }
        }
        return normal(side: side, height: pixels)
    }

    private static func heightMap(side: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: side * side)
        let space = CGColorSpaceCreateDeviceGray()
        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side,
                space: space,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return }
            let s = CGFloat(side)
            let center = CGPoint(x: s / 2, y: s / 2)
            context.setFillColor(gray: 0.5, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: s, height: s))
            context.setLineWidth(s / 300)
            context.setStrokeColor(gray: 1, alpha: 0.9)
            let radius = s * 0.2
            for step in 0..<40 {
                let angle = CGFloat(step) / 40 * 2 * .pi
                let origin = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                context.strokeEllipse(in: CGRect(x: origin.x - radius, y: origin.y - radius, width: radius * 2, height: radius * 2))
            }
            context.setStrokeColor(gray: 0.15, alpha: 0.8)
            context.setLineWidth(s / 900)
            var ring = s * 0.43
            while ring < s * 0.5 {
                context.strokeEllipse(in: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2))
                ring += s / 260
            }
        }
        return pixels
    }

    private static func color(side: Int, height: [UInt8]) -> UIImage {
        var rgba = [UInt8](repeating: 255, count: side * side * 4)
        let s = Float(side)
        for y in 0..<side {
            for x in 0..<side {
                let dx = (Float(x) - s * 0.4) / s
                let dy = (Float(y) - s * 0.3) / s
                let shade = max(0, 1 - sqrt(dx * dx + dy * dy) * 1.3)
                let lift = (Float(height[y * side + x]) - 128) / 128 * 0.1
                let i = (y * side + x) * 4
                rgba[i] = UInt8(max(0, min(255, (0.09 + 0.08 * shade + lift) * 255)))
                rgba[i + 1] = UInt8(max(0, min(255, (0.17 + 0.12 * shade + lift) * 255)))
                rgba[i + 2] = UInt8(max(0, min(255, (0.48 + 0.2 * shade + lift) * 255)))
            }
        }
        return image(rgba, side: side)
    }

    private static func normal(side: Int, height: [UInt8]) -> UIImage {
        var rgba = [UInt8](repeating: 255, count: side * side * 4)
        let strength: Float = 3.5
        for y in 0..<side {
            for x in 0..<side {
                let left = Float(height[y * side + max(0, x - 1)])
                let right = Float(height[y * side + min(side - 1, x + 1)])
                let up = Float(height[max(0, y - 1) * side + x])
                let down = Float(height[min(side - 1, y + 1) * side + x])
                var nx = (left - right) / 255 * strength
                var ny = (down - up) / 255 * strength
                var nz: Float = 1
                let length = sqrt(nx * nx + ny * ny + nz * nz)
                nx /= length
                ny /= length
                nz /= length
                let i = (y * side + x) * 4
                rgba[i] = UInt8((nx * 0.5 + 0.5) * 255)
                rgba[i + 1] = UInt8((ny * 0.5 + 0.5) * 255)
                rgba[i + 2] = UInt8((nz * 0.5 + 0.5) * 255)
            }
        }
        return image(rgba, side: side)
    }

    private static func image(_ rgba: [UInt8], side: Int) -> UIImage {
        var bytes = rgba
        let space = CGColorSpaceCreateDeviceRGB()
        let made = bytes.withUnsafeMutableBytes { buffer -> CGImage? in
            CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )?.makeImage()
        }
        return made.map(UIImage.init(cgImage:)) ?? UIImage()
    }
}
