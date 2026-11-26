// Renders the real widget views with fictional data into docs/*.png (see tools/render_docs.sh)
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs"
NSApplication.shared.setActivationPolicy(.accessory)
let dark = NSAppearance(named: .darkAqua)!

func png(_ rep: NSBitmapImageRep, _ name: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}

// --- Menu mock: three cards on a menu-like dark panel
let cards = [
    Card(name: "account-a", weekLeft: 191940.0, weekDate: "Sun 29 Nov, 05:00", weekUsed: 0.68, isActive: true,
         weekUtil: 0.64, winUtil: 1.04, winLeft: 4980.0, winClock: "01:04", winOpen: true),
    Card(name: "account-b", weekLeft: 371820.0, weekDate: "Tue 1 Dec, 07:00", weekUsed: 0.38, isActive: false,
         weekUtil: 0.40, winUtil: 0.50, winLeft: 10620.0, winClock: "02:40", winOpen: true),
    Card(name: "account-c", weekLeft: 587940.0, weekDate: "Thu 3 Dec, 19:00", weekUsed: 0.02, isActive: false,
         weekUtil: 0.01, winUtil: 0.07, winLeft: 17160.0, winClock: "04:27", winOpen: true),
]
let pad: CGFloat = 10
let views = cards.map { CardView($0) }
var panelH: CGFloat = pad * 2
for v in views { panelH += v.frame.height + 12 }
panelH -= 12
let panel = NSView(frame: NSRect(x: 0, y: 0, width: 380 + pad * 2, height: panelH))
panel.appearance = dark
panel.wantsLayer = true
panel.layer?.backgroundColor = NSColor(calibratedWhite: 0.16, alpha: 1).cgColor
panel.layer?.cornerRadius = 14
var y = pad
for v in views.reversed() { v.frame.origin = NSPoint(x: pad, y: y); v.appearance = dark; panel.addSubview(v); y += v.frame.height + 12 }
let scale: CGFloat = 2
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(panel.frame.width * scale), pixelsHigh: Int(panel.frame.height * scale),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = panel.frame.size
panel.cacheDisplay(in: panel.bounds, to: rep)
png(rep, "menu")

// --- Menu bar strip: battery bar in three saturation states
let app = App()
let states: [(String, Double?, Double?)] = [("account-a", 0.12, 0.30), ("account-b", 0.72, 0.55), ("account-c", 1.04, 0.64)]
let imgs = states.map { app.statusImage($0) }
var maxW: CGFloat = 0
for im in imgs { maxW = max(maxW, im.size.width) }
let stripW: CGFloat = maxW + 40
let rowH: CGFloat = 34
let nRows = CGFloat(imgs.count)
let strip = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(stripW * scale), pixelsHigh: Int(rowH * nRows * scale),
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
strip.size = NSSize(width: stripW, height: rowH * nRows)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: strip)
NSAppearance.current = dark
NSColor(calibratedWhite: 0.16, alpha: 1).setFill(); NSRect(origin: .zero, size: strip.size).fill()
for (i, im) in imgs.enumerated() {
    let row: CGFloat = CGFloat(imgs.count - 1 - i)
    let yy: CGFloat = rowH * row + (rowH - im.size.height) / 2
    im.draw(at: NSPoint(x: 20, y: yy), from: .zero, operation: .sourceOver, fraction: 1)
}
NSGraphicsContext.restoreGraphicsState()
png(strip, "menubar")
print("ok")
