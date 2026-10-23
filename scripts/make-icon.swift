import AppKit
let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let background = NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 215, yRadius: 215)
NSGradient(starting: NSColor(calibratedRed: 0.12, green: 0.24, blue: 0.29, alpha: 1), ending: NSColor(calibratedRed: 0.04, green: 0.12, blue: 0.17, alpha: 1))!.draw(in: background, angle: -60)
let back = NSBezierPath(roundedRect: NSRect(x: 280, y: 245, width: 510, height: 570), xRadius: 72, yRadius: 72)
NSColor(calibratedRed: 0.24, green: 0.81, blue: 0.69, alpha: 0.45).setFill()
back.fill()
let front = NSBezierPath(roundedRect: NSRect(x: 214, y: 184, width: 510, height: 570), xRadius: 72, yRadius: 72)
NSColor(calibratedRed: 0.47, green: 0.94, blue: 0.79, alpha: 1).setFill()
front.fill()
let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 360, weight: .bold), .foregroundColor: NSColor(calibratedRed: 0.06, green: 0.20, blue: 0.23, alpha: 1)]
let label = NSAttributedString(string: "X", attributes: attributes)
label.draw(at: NSPoint(x: 347, y: 245))
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
