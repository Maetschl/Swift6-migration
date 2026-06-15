#!/usr/bin/env swift
import AppKit
import Foundation

struct IconVariant {
    let filename: String
    let pixels: Int
}

let variants = [
    IconVariant(filename: "icon_16x16.png", pixels: 16),
    IconVariant(filename: "icon_16x16@2x.png", pixels: 32),
    IconVariant(filename: "icon_32x32.png", pixels: 32),
    IconVariant(filename: "icon_32x32@2x.png", pixels: 64),
    IconVariant(filename: "icon_128x128.png", pixels: 128),
    IconVariant(filename: "icon_128x128@2x.png", pixels: 256),
    IconVariant(filename: "icon_256x256.png", pixels: 256),
    IconVariant(filename: "icon_256x256@2x.png", pixels: 512),
    IconVariant(filename: "icon_512x512.png", pixels: 512),
    IconVariant(filename: "icon_512x512@2x.png", pixels: 1024),
]

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate-app-icon.swift <output.icns>\n", stderr)
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default
let tempRoot = fileManager.temporaryDirectory
    .appendingPathComponent("swift6-analyzer-icon-\(UUID().uuidString)", isDirectory: true)
let iconsetURL = tempRoot.appendingPathComponent("AppIcon.iconset", isDirectory: true)

try fileManager.createDirectory(
    at: iconsetURL,
    withIntermediateDirectories: true
)
try fileManager.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

for variant in variants {
    let rep = renderIcon(pixels: variant.pixels)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fputs("failed to render \(variant.filename)\n", stderr)
        exit(1)
    }
    try data.write(to: iconsetURL.appendingPathComponent(variant.filename))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c", "icns",
    iconsetURL.path,
    "-o", outputURL.path
]

try process.run()
process.waitUntilExit()

try? fileManager.removeItem(at: tempRoot)

if process.terminationStatus != 0 {
    fputs("iconutil failed with exit code \(process.terminationStatus)\n", stderr)
    exit(process.terminationStatus)
}

func renderIcon(pixels: Int) -> NSBitmapImageRep {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let iconRect = rect.insetBy(dx: size * 0.035, dy: size * 0.035)
    let iconPath = NSBezierPath(
        roundedRect: iconRect,
        xRadius: size * 0.205,
        yRadius: size * 0.205
    )

    let backgroundShadow = NSShadow()
    backgroundShadow.shadowBlurRadius = size * 0.035
    backgroundShadow.shadowOffset = NSSize(width: 0, height: -size * 0.015)
    backgroundShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    backgroundShadow.set()

    NSGradient(
        colors: [
            NSColor(hex: 0x1D1D1F),
            NSColor(hex: 0x243249),
            NSColor(hex: 0x0F7A65)
        ]
    )!.draw(in: iconPath, angle: -45)

    NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

    let glowPath = NSBezierPath(
        roundedRect: iconRect.insetBy(dx: size * 0.07, dy: size * 0.07),
        xRadius: size * 0.14,
        yRadius: size * 0.14
    )
    NSColor.white.withAlphaComponent(0.10).setFill()
    glowPath.fill()

    drawCodeLines(in: rect, size: size)
    drawMagnifier(in: rect, size: size)
    drawSwiftSix(in: rect, size: size)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func drawCodeLines(in rect: NSRect, size: CGFloat) {
    let lineHeight = size * 0.035
    let lineRadius = lineHeight * 0.5
    let left = size * 0.22
    let top = size * 0.69
    let widths = [size * 0.29, size * 0.20, size * 0.25]

    for index in 0..<3 {
        let y = top - CGFloat(index) * size * 0.075
        let lineRect = NSRect(
            x: left,
            y: y,
            width: widths[index],
            height: lineHeight
        )
        let line = NSBezierPath(
            roundedRect: lineRect,
            xRadius: lineRadius,
            yRadius: lineRadius
        )
        NSColor.white.withAlphaComponent(index == 1 ? 0.32 : 0.22).setFill()
        line.fill()
    }
}

func drawMagnifier(in rect: NSRect, size: CGFloat) {
    let lensRect = NSRect(
        x: size * 0.53,
        y: size * 0.50,
        width: size * 0.28,
        height: size * 0.28
    )

    let handle = NSBezierPath()
    handle.lineWidth = max(2, size * 0.045)
    handle.lineCapStyle = .round
    handle.move(to: NSPoint(x: size * 0.735, y: size * 0.50))
    handle.line(to: NSPoint(x: size * 0.83, y: size * 0.39))
    NSColor.white.withAlphaComponent(0.92).setStroke()
    handle.stroke()

    let lens = NSBezierPath(ovalIn: lensRect)
    NSColor.white.withAlphaComponent(0.16).setFill()
    lens.fill()
    lens.lineWidth = max(2, size * 0.035)
    NSColor.white.withAlphaComponent(0.94).setStroke()
    lens.stroke()

    let check = NSBezierPath()
    check.lineWidth = max(2, size * 0.026)
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    check.move(to: NSPoint(x: size * 0.603, y: size * 0.625))
    check.line(to: NSPoint(x: size * 0.648, y: size * 0.58))
    check.line(to: NSPoint(x: size * 0.725, y: size * 0.675))
    NSColor(hex: 0x36D17B).setStroke()
    check.stroke()
}

func drawSwiftSix(in rect: NSRect, size: CGFloat) {
    let number = "6" as NSString
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.52, weight: .heavy),
        .foregroundColor: NSColor(hex: 0xFF9F2D),
        .kern: -size * 0.02
    ]
    let numberSize = number.size(withAttributes: attributes)
    let numberPoint = NSPoint(
        x: size * 0.215,
        y: size * 0.185
    )

    let shadow = NSShadow()
    shadow.shadowBlurRadius = size * 0.018
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.01)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.set()
    number.draw(at: numberPoint, withAttributes: attributes)

    NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

    let swift = "Swift" as NSString
    let labelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.085, weight: .bold),
        .foregroundColor: NSColor.white.withAlphaComponent(0.72),
        .kern: size * 0.001
    ]
    let labelSize = swift.size(withAttributes: labelAttributes)
    swift.draw(
        at: NSPoint(
            x: numberPoint.x + max(0, (numberSize.width - labelSize.width) * 0.5),
            y: size * 0.205
        ),
        withAttributes: labelAttributes
    )
}

extension NSColor {
    convenience init(hex: Int) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: 1
        )
    }
}
