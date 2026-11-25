import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Draws the 1024×1024 AgentDot app icon.
// Usage: swift scripts/generate-icon.swift <output.png>

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/AppIcon.png"

let canvas: CGFloat = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: Int(canvas),
    height: Int(canvas),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("cannot create bitmap context\n", stderr)
    exit(1)
}

ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)
ctx.interpolationQuality = .high

func rgba(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func gradient(_ colors: [CGColor], _ stops: [CGFloat]) -> CGGradient {
    CGGradient(
        colorsSpace: colorSpace,
        colors: colors as CFArray,
        locations: stops
    )!
}

// Apple's macOS icon grid: 824×824 content area inside a 1024 canvas.
let content = CGRect(x: 100, y: 100, width: 824, height: 824)
let corner: CGFloat = 185
let backgroundPath = CGPath(
    roundedRect: content,
    cornerWidth: corner,
    cornerHeight: corner,
    transform: nil
)

// Soft drop shadow under the rounded square.
ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: -18),
    blur: 38,
    color: rgba(0x000000, 0.38)
)
ctx.addPath(backgroundPath)
ctx.setFillColor(rgba(0x0A0C14))
ctx.fillPath()
ctx.restoreGState()

// Background.
ctx.saveGState()
ctx.addPath(backgroundPath)
ctx.clip()

let background = gradient(
    [rgba(0x242B45), rgba(0x101423), rgba(0x05060A)],
    [0, 0.52, 1]
)
ctx.drawLinearGradient(
    background,
    start: CGPoint(x: canvas / 2, y: content.maxY),
    end: CGPoint(x: canvas / 2, y: content.minY),
    options: []
)

let greenGlow = gradient(
    [rgba(0x34D399, 0.18), rgba(0x34D399, 0.0)],
    [0, 1]
)
ctx.drawRadialGradient(
    greenGlow,
    startCenter: CGPoint(x: 512, y: 500),
    startRadius: 0,
    endCenter: CGPoint(x: 512, y: 500),
    endRadius: 410,
    options: []
)

// Subtle top-left highlight.
let highlight = gradient(
    [rgba(0xFFFFFF, 0.08), rgba(0xFFFFFF, 0.0)],
    [0, 1]
)
ctx.drawLinearGradient(
    highlight,
    start: CGPoint(x: content.minX, y: content.maxY),
    end: CGPoint(x: content.midX, y: content.midY),
    options: []
)
ctx.restoreGState()

// Inner rim.
ctx.addPath(
    CGPath(
        roundedRect: content.insetBy(dx: 2, dy: 2),
        cornerWidth: corner - 2,
        cornerHeight: corner - 2,
        transform: nil
    )
)
ctx.setStrokeColor(rgba(0xFFFFFF, 0.10))
ctx.setLineWidth(3)
ctx.strokePath()

// Progress ring, open at the top right for the alert badge.
let center = CGPoint(x: 512, y: 500)
let radius: CGFloat = 236
let ringWidth: CGFloat = 74
let startAngle = 68.0 * .pi / 180
let endAngle = 22.0 * .pi / 180

let ring = CGMutablePath()
ring.addArc(
    center: center,
    radius: radius,
    startAngle: startAngle,
    endAngle: endAngle,
    clockwise: false
)

// Green glow underneath the ring.
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 36, color: rgba(0x10B981, 0.55))
ctx.addPath(ring)
ctx.setStrokeColor(rgba(0x10B981, 0.9))
ctx.setLineWidth(ringWidth)
ctx.setLineCap(.round)
ctx.strokePath()
ctx.restoreGState()

// Gradient stroke on top of the glow.
ctx.saveGState()
ctx.addPath(ring)
ctx.setLineWidth(ringWidth)
ctx.setLineCap(.round)
ctx.replacePathWithStrokedPath()
ctx.clip()
let ringGradient = gradient(
    [rgba(0x6EE7B7), rgba(0x34D399), rgba(0x059669)],
    [0, 0.52, 1]
)
ctx.drawLinearGradient(
    ringGradient,
    start: CGPoint(x: 300, y: 800),
    end: CGPoint(x: 740, y: 210),
    options: []
)
ctx.restoreGState()

// Center ball.
let ballRadius: CGFloat = 138
let ballRect = CGRect(
    x: center.x - ballRadius,
    y: center.y - ballRadius,
    width: ballRadius * 2,
    height: ballRadius * 2
)
ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: -10),
    blur: 30,
    color: rgba(0x000000, 0.45)
)
ctx.setFillColor(rgba(0xF8FAFC))
ctx.fillEllipse(in: ballRect)
ctx.restoreGState()

ctx.saveGState()
ctx.addEllipse(in: ballRect)
ctx.clip()
let ballGradient = gradient(
    [rgba(0xFFFFFF), rgba(0xE7EDF5), rgba(0xCBD5E3)],
    [0, 0.55, 1]
)
ctx.drawLinearGradient(
    ballGradient,
    start: CGPoint(x: center.x, y: center.y + ballRadius),
    end: CGPoint(x: center.x, y: center.y - ballRadius),
    options: []
)
ctx.restoreGState()

// Small green core makes the dot readable at 16×16.
let coreRadius: CGFloat = 46
let coreRect = CGRect(
    x: center.x - coreRadius,
    y: center.y - coreRadius,
    width: coreRadius * 2,
    height: coreRadius * 2
)
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 18, color: rgba(0x10B981, 0.35))
ctx.setFillColor(rgba(0x10B981))
ctx.fillEllipse(in: coreRect)
ctx.restoreGState()
ctx.saveGState()
ctx.addEllipse(in: coreRect)
ctx.clip()
let coreGradient = gradient(
    [rgba(0x6EE7B7), rgba(0x10B981)],
    [0, 1]
)
ctx.drawLinearGradient(
    coreGradient,
    start: CGPoint(x: center.x, y: center.y + coreRadius),
    end: CGPoint(x: center.x, y: center.y - coreRadius),
    options: []
)
ctx.restoreGState()

// Red authorization badge on the ring gap.
let badgeCenter = CGPoint(x: 712, y: 706)
let badgeRadius: CGFloat = 82
let cutoutRadius: CGFloat = 104
let cutoutRect = CGRect(
    x: badgeCenter.x - cutoutRadius,
    y: badgeCenter.y - cutoutRadius,
    width: cutoutRadius * 2,
    height: cutoutRadius * 2
)
ctx.setFillColor(rgba(0x0B0E18))
ctx.fillEllipse(in: cutoutRect)

let badgeRect = CGRect(
    x: badgeCenter.x - badgeRadius,
    y: badgeCenter.y - badgeRadius,
    width: badgeRadius * 2,
    height: badgeRadius * 2
)
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 28, color: rgba(0xEF4444, 0.6))
ctx.setFillColor(rgba(0xEF4444))
ctx.fillEllipse(in: badgeRect)
ctx.restoreGState()

ctx.saveGState()
ctx.addEllipse(in: badgeRect)
ctx.clip()
let badgeGradient = gradient(
    [rgba(0xFF8A8A), rgba(0xF43F5E), rgba(0xC81E3C)],
    [0, 0.52, 1]
)
ctx.drawLinearGradient(
    badgeGradient,
    start: CGPoint(x: badgeCenter.x, y: badgeCenter.y + badgeRadius),
    end: CGPoint(x: badgeCenter.x, y: badgeCenter.y - badgeRadius),
    options: []
)
ctx.restoreGState()

// White glint on the badge.
ctx.setFillColor(rgba(0xFFFFFF, 0.28))
ctx.fillEllipse(
    in: CGRect(
        x: badgeCenter.x - 44,
        y: badgeCenter.y + 10,
        width: 58,
        height: 34
    )
)

guard let image = ctx.makeImage() else {
    fputs("cannot render image\n", stderr)
    exit(1)
}
let url = URL(fileURLWithPath: outputPath)
guard let destination = CGImageDestinationCreateWithURL(
    url as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    fputs("cannot create image destination\n", stderr)
    exit(1)
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("cannot write png\n", stderr)
    exit(1)
}
print("wrote \(outputPath)")
