#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate-icon.swift <output.icns>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default
let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent("apfel-clip-icon-\(UUID().uuidString)")
let iconsetURL = tempDirectory.appendingPathComponent("AppIcon.iconset")

try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let baseSizes = [16, 32, 128, 256, 512]
for baseSize in baseSizes {
    try writeIcon(baseSize: baseSize, scale: 1, iconsetURL: iconsetURL)
    try writeIcon(baseSize: baseSize, scale: 2, iconsetURL: iconsetURL)
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
    throw NSError(domain: "generate-icon", code: Int(iconutil.terminationStatus), userInfo: [
        NSLocalizedDescriptionKey: "iconutil failed with exit code \(iconutil.terminationStatus)"
    ])
}

try? fileManager.removeItem(at: tempDirectory)

func writeIcon(baseSize: Int, scale: Int, iconsetURL: URL) throws {
    let pixelSize = CGFloat(baseSize * scale)
    let image = drawIcon(pixelSize: pixelSize)
    let representation = NSBitmapImageRep(data: image.tiffRepresentation ?? Data())

    guard let pngData = representation?.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "generate-icon", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Failed to encode PNG for \(baseSize)x\(baseSize)@\(scale)x"
        ])
    }

    let filename: String
    if scale == 1 {
        filename = "icon_\(baseSize)x\(baseSize).png"
    } else {
        filename = "icon_\(baseSize)x\(baseSize)@2x.png"
    }

    try pngData.write(to: iconsetURL.appendingPathComponent(filename))
}

func drawIcon(pixelSize: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    NSColor.clear.setFill()
    rect.fill()

    let inset = pixelSize * 0.06
    let cardRect = rect.insetBy(dx: inset, dy: inset)
    let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: pixelSize * 0.22, yRadius: pixelSize * 0.22)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.12, green: 0.50, blue: 0.24, alpha: 1),
        NSColor(calibratedRed: 0.76, green: 0.84, blue: 0.24, alpha: 1)
    ])!
    gradient.draw(in: cardPath, angle: 90)

    NSColor(calibratedWhite: 1, alpha: 0.15).setStroke()
    cardPath.lineWidth = max(2, pixelSize * 0.03)
    cardPath.stroke()

    let clipboardRect = NSRect(
        x: pixelSize * 0.22,
        y: pixelSize * 0.18,
        width: pixelSize * 0.44,
        height: pixelSize * 0.56
    )
    let clipboardPath = NSBezierPath(roundedRect: clipboardRect, xRadius: pixelSize * 0.07, yRadius: pixelSize * 0.07)
    NSColor(calibratedWhite: 1, alpha: 0.92).setFill()
    clipboardPath.fill()

    let clipTopRect = NSRect(
        x: pixelSize * 0.30,
        y: pixelSize * 0.63,
        width: pixelSize * 0.28,
        height: pixelSize * 0.12
    )
    let clipTopPath = NSBezierPath(roundedRect: clipTopRect, xRadius: pixelSize * 0.05, yRadius: pixelSize * 0.05)
    NSColor(calibratedRed: 0.93, green: 0.97, blue: 0.90, alpha: 1).setFill()
    clipTopPath.fill()

    let lineColor = NSColor(calibratedRed: 0.18, green: 0.42, blue: 0.19, alpha: 0.85)
    let lineWidth = max(2, pixelSize * 0.028)
    for y in [0.52, 0.43, 0.34] {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: pixelSize * 0.28, y: pixelSize * y))
        path.line(to: NSPoint(x: pixelSize * 0.58, y: pixelSize * y))
        path.lineWidth = lineWidth
        lineColor.setStroke()
        path.stroke()
    }

    let sparkleCenter = NSPoint(x: pixelSize * 0.74, y: pixelSize * 0.66)
    let sparkle = NSBezierPath()
    sparkle.move(to: NSPoint(x: sparkleCenter.x, y: sparkleCenter.y + pixelSize * 0.10))
    sparkle.line(to: NSPoint(x: sparkleCenter.x + pixelSize * 0.04, y: sparkleCenter.y + pixelSize * 0.04))
    sparkle.line(to: NSPoint(x: sparkleCenter.x + pixelSize * 0.10, y: sparkleCenter.y))
    sparkle.line(to: NSPoint(x: sparkleCenter.x + pixelSize * 0.04, y: sparkleCenter.y - pixelSize * 0.04))
    sparkle.line(to: NSPoint(x: sparkleCenter.x, y: sparkleCenter.y - pixelSize * 0.10))
    sparkle.line(to: NSPoint(x: sparkleCenter.x - pixelSize * 0.04, y: sparkleCenter.y - pixelSize * 0.04))
    sparkle.line(to: NSPoint(x: sparkleCenter.x - pixelSize * 0.10, y: sparkleCenter.y))
    sparkle.line(to: NSPoint(x: sparkleCenter.x - pixelSize * 0.04, y: sparkleCenter.y + pixelSize * 0.04))
    sparkle.close()
    NSColor(calibratedRed: 1, green: 0.95, blue: 0.68, alpha: 0.95).setFill()
    sparkle.fill()

    image.unlockFocus()
    return image
}
