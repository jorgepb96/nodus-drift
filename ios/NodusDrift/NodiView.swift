// SPDX-License-Identifier: MIT
// Native vector adaptation of Nodus's Nodi.tsx and DRIFT's lotus pose.
import SwiftUI

enum DriftTheme {
    static let background = Color(hex: 0x0C1414)
    static let panel = Color(hex: 0x152020)
    static let accent = Color(hex: 0xBCD4BA)
    static let muted = Color(hex: 0xA0B2AD)
    static let text = Color(hex: 0xF0F1E8)
    static let line = Color.white.opacity(0.09)
}
extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct NodiView: View {
    var awake = false
    var gaze = CGPoint.zero
    var immersive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private static let mesh: [(point: CGPoint, z: Double)] = (0..<58).map { i in
        let y = 1 - Double(i) / 57 * 2, radius = sqrt(max(0, 1 - y * y)), angle = Double(i) * 2.399963229
        return (CGPoint(x: 130 + cos(angle) * radius * 52, y: 140 - y * 52), sin(angle) * radius)
    }
    private static let meshLines: [(a: CGPoint, b: CGPoint, depth: Double)] = {
        var result: [(a: CGPoint, b: CGPoint, depth: Double)] = []
        var connections = Set<String>()
        for (index, node) in mesh.enumerated() {
            let closest = mesh.indices.filter { $0 != index }.sorted { a, b in
                hypot(node.point.x - mesh[a].point.x, node.point.y - mesh[a].point.y) < hypot(node.point.x - mesh[b].point.x, node.point.y - mesh[b].point.y)
            }.prefix(3)
            for other in closest {
                let key = "\(min(index, other))_\(max(index, other))"
                guard connections.insert(key).inserted, hypot(node.point.x - mesh[other].point.x, node.point.y - mesh[other].point.y) <= 52 * 0.82 else { continue }
                result.append((node.point, mesh[other].point, (node.z + mesh[other].z + 2) / 4))
            }
        }
        return result
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || scenePhase != .active)) { time in
            Canvas { context, size in
                let t = reduceMotion ? 0 : time.date.timeIntervalSinceReferenceDate
                let breathe = sin(t * .pi / 3) * 2
                let scale = min(size.width / 270, size.height / 220)
                context.translateBy(x: (size.width - 270 * scale) / 2, y: (size.height - 220 * scale) / 2)
                context.scaleBy(x: scale, y: scale)
                context.translateBy(x: 5, y: -37)
                func ellipse(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double) -> Path {
                    Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2))
                }
                for n in 0..<3 {
                    let radius = Double(80 + n * 24)
                    let ripple = ellipse(130, 244, radius, Double(7 + n * 4))
                    context.stroke(ripple, with: .color(DriftTheme.accent.opacity(Double(3 - n) * 0.045)), lineWidth: 0.7)
                }
                context.translateBy(x: 0, y: breathe)
                let bodyColor = Gradient(colors: [Color(hex: 0xFFFEFA), Color(hex: 0xFBF3DE), Color(hex: 0xF2E4C2), Color(hex: 0xE7D5AC)])
                let pearlColor = Gradient(colors: [Color(hex: 0xFFFEF6), Color(hex: 0xF6EAC9), Color(hex: 0xE4D0A2)])
                context.fill(ellipse(130, 140, 90, 90), with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF6D6).opacity(immersive ? 0.16 : 0.08), .clear]), center: CGPoint(x: 130, y: 140), startRadius: 0, endRadius: 90))
                func thread(_ path: Path) {
                    context.stroke(path, with: .color(Color(hex: 0xD4AF37)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                }
                func pearl(_ x: Double, _ y: Double) {
                    var glow = context
                    glow.addFilter(.shadow(color: Color(hex: 0xFFEFC0).opacity(0.35), radius: 4))
                    glow.fill(ellipse(x, y, 9, 9), with: .radialGradient(pearlColor, center: CGPoint(x: x - 3, y: y - 3), startRadius: 0, endRadius: 13))
                    context.stroke(ellipse(x, y, 9, 9), with: .color(Color(hex: 0xD4AF37).opacity(0.85)), lineWidth: 1.5)
                    context.fill(ellipse(x - 3, y - 3, 2.4, 1.7), with: .color(.white.opacity(0.85)))
                }
                thread(Path { p in p.move(to: CGPoint(x: 92, y: 150)); p.addCurve(to: CGPoint(x: 64, y: 207), control1: CGPoint(x: 76, y: 165), control2: CGPoint(x: 66, y: 184)) })
                thread(Path { p in p.move(to: CGPoint(x: 168, y: 150)); p.addCurve(to: CGPoint(x: 196, y: 207), control1: CGPoint(x: 184, y: 165), control2: CGPoint(x: 194, y: 184)) })
                thread(Path { p in p.move(to: CGPoint(x: 112, y: 190)); p.addCurve(to: CGPoint(x: 87, y: 223), control1: CGPoint(x: 104, y: 202), control2: CGPoint(x: 97, y: 215)); p.addCurve(to: CGPoint(x: 170, y: 224), control1: CGPoint(x: 72, y: 239), control2: CGPoint(x: 129, y: 239)) })
                thread(Path { p in p.move(to: CGPoint(x: 150, y: 192)); p.addCurve(to: CGPoint(x: 179, y: 224), control1: CGPoint(x: 158, y: 203), control2: CGPoint(x: 165, y: 216)); p.addCurve(to: CGPoint(x: 96, y: 224), control1: CGPoint(x: 190, y: 240), control2: CGPoint(x: 132, y: 239)) })
                pearl(64, 207); pearl(196, 207); pearl(170, 224); pearl(96, 224)
                context.fill(ellipse(130, 140, 56, 56), with: .radialGradient(bodyColor, center: CGPoint(x: 119, y: 118), startRadius: 0, endRadius: 84))
                var meshContext = context
                meshContext.clip(to: ellipse(130, 140, 56, 56))
                for line in Self.meshLines {
                    let path = Path { p in p.move(to: line.a); p.addLine(to: line.b) }
                    meshContext.stroke(path, with: .color(Color(hex: 0xFFFCEC).opacity(0.05 + line.depth * 0.2)), lineWidth: 0.4 + line.depth * 0.4)
                }
                for node in Self.mesh {
                    let depth = (node.z + 1) / 2
                    meshContext.fill(ellipse(node.point.x, node.point.y, 0.7 + depth * 0.6, 0.7 + depth * 0.6), with: .color(.white.opacity(0.18 + depth * 0.35)))
                }
                var highlight = context
                highlight.addFilter(.blur(radius: 2.2))
                highlight.stroke(ellipse(130, 140, 55, 55), with: .color(Color(hex: 0xFFFDF2).opacity(0.65)), lineWidth: 4)
                highlight.fill(ellipse(110, 114, 20, 13), with: .color(.white.opacity(0.45)))
                context.translateBy(x: gaze.x, y: gaze.y)
                if awake {
                    let eyes = Gradient(colors: [Color(hex: 0x7A5330), Color(hex: 0x3A2412), Color(hex: 0x160C04)])
                    for x in [113.0, 147.0] {
                        context.fill(ellipse(x, 139, 5.4, 7.6), with: .radialGradient(eyes, center: CGPoint(x: x - 1, y: 136), startRadius: 0, endRadius: 9))
                        context.fill(ellipse(x + 2, 135, 1.7, 1.7), with: .color(.white.opacity(0.92)))
                        context.fill(ellipse(x - 1, 143, 1, 1), with: .color(Color(hex: 0xE9C58A).opacity(0.7)))
                    }
                } else {
                    for x in [107.0, 141.0] {
                        let eye = Path { p in p.move(to: CGPoint(x: x, y: 139)); p.addQuadCurve(to: CGPoint(x: x + 12, y: 139), control: CGPoint(x: x + 6, y: 144)) }
                        context.stroke(eye, with: .color(Color(hex: 0x2A1A0C).opacity(0.85)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    }
                }
                let mouth = Path { p in p.move(to: CGPoint(x: 123, y: 158)); p.addQuadCurve(to: CGPoint(x: 137, y: 158), control: CGPoint(x: 130, y: 164)) }
                context.stroke(mouth, with: .color(Color(hex: 0x9A5F38)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nodi")
        .accessibilityValue(awake ? "Awake" : "Meditating")
        .accessibilityIdentifier("nodi")
    }
}
