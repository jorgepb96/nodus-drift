// SPDX-License-Identifier: MIT
// Reproduce the app icon from Nodi's original vector geometry.
import AppKit
import CoreGraphics
let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
c.translateBy(x: 0, y: 1024); c.scaleBy(x: 1, y: -1)
func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor { CGColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha) }
c.setFillColor(color(0x0C1414)); c.fill(CGRect(x:0,y:0,width:1024,height:1024))
let halo = CGGradient(colorsSpace: colorSpace, colors: [color(0x556149,0.28),color(0x0C1414,0)] as CFArray, locations: [0,1])!
c.drawRadialGradient(halo, startCenter: CGPoint(x:512,y:512),startRadius:0,endCenter:CGPoint(x:512,y:512),endRadius:490,options:[])
// Center the complete painted character and ripples, rather than the source canvas.
let iconScale: CGFloat = 3.75
let paintedCenter = CGPoint(x: 130, y: (84 + 259) / 2)
c.saveGState()
c.translateBy(x: 512 - paintedCenter.x * iconScale, y: 512 - paintedCenter.y * iconScale)
c.scaleBy(x: iconScale, y: iconScale)
func ellipse(_ x:CGFloat,_ y:CGFloat,_ rx:CGFloat,_ ry:CGFloat) -> CGRect { CGRect(x:x-rx,y:y-ry,width:rx*2,height:ry*2) }
c.setStrokeColor(color(0xBCD4BA,0.14)); c.setLineWidth(0.7)
for i in 0..<3 { c.strokeEllipse(in:ellipse(130,244,CGFloat(82+i*24),CGFloat(7+i*4))) }
c.setStrokeColor(color(0xD4AF37)); c.setLineWidth(1.6); c.setLineCap(.round)
func thread(_ x:CGFloat,_ y:CGFloat,_ a:CGFloat,_ b:CGFloat,_ d:CGFloat,_ e:CGFloat,_ f:CGFloat,_ g:CGFloat) { c.move(to:CGPoint(x:x,y:y));c.addCurve(to:CGPoint(x:f,y:g),control1:CGPoint(x:a,y:b),control2:CGPoint(x:d,y:e)); c.strokePath() }
thread(92,150,76,165,66,184,64,207);thread(168,150,184,165,194,184,196,207)
c.move(to:CGPoint(x:112,y:190));c.addCurve(to:CGPoint(x:87,y:223),control1:CGPoint(x:104,y:202),control2:CGPoint(x:97,y:215));c.addCurve(to:CGPoint(x:170,y:224),control1:CGPoint(x:72,y:239),control2:CGPoint(x:129,y:239));c.strokePath()
c.move(to:CGPoint(x:150,y:192));c.addCurve(to:CGPoint(x:179,y:224),control1:CGPoint(x:158,y:203),control2:CGPoint(x:165,y:216));c.addCurve(to:CGPoint(x:96,y:224),control1:CGPoint(x:190,y:240),control2:CGPoint(x:132,y:239));c.strokePath()
func sphere(_ x:CGFloat,_ y:CGFloat,_ r:CGFloat) {
 c.saveGState();c.setShadow(offset:.zero,blur:6,color:color(0xFFEFC0,0.2));c.addEllipse(in:ellipse(x,y,r,r));c.clip()
 let g = CGGradient(colorsSpace:colorSpace,colors:[color(0xFFFEFA),color(0xFBF3DE),color(0xF2E4C2),color(0xE7D5AC)] as CFArray,locations:[0,0.4,0.78,1])!
 c.drawRadialGradient(g,startCenter:CGPoint(x:x-r*0.2,y:y-r*0.4),startRadius:0,endCenter:CGPoint(x:x-r*0.2,y:y-r*0.4),endRadius:r*1.5,options:[.drawsAfterEndLocation]);c.restoreGState()
}
for (x,y) in [(64.0,207.0),(196.0,207.0),(170.0,224.0),(96.0,224.0)] {sphere(x,y,9);c.setStrokeColor(color(0xD4AF37));c.strokeEllipse(in:ellipse(x,y,9,9))}
sphere(130,140,56)
c.setStrokeColor(color(0xFFFCEC,0.17));c.setFillColor(color(0xFFFFFF,0.32));c.setLineWidth(0.4)
var pts=[CGPoint]()
for i in 0..<58 { let y=1-Double(i)/57*2; let rr=sqrt(max(0,1-y*y));let th=Double(i)*2.399963229;pts.append(CGPoint(x:130+cos(th)*rr*52,y:140-y*52)) }
for i in pts.indices { let neighbors=pts.indices.filter{$0 != i}.sorted{ hypot(pts[i].x-pts[$0].x,pts[i].y-pts[$0].y)<hypot(pts[i].x-pts[$1].x,pts[i].y-pts[$1].y) }.prefix(3);for j in neighbors {c.move(to:pts[i]);c.addLine(to:pts[j]);c.strokePath()};c.fillEllipse(in:ellipse(pts[i].x,pts[i].y,0.8,0.8)) }
c.setStrokeColor(color(0x2A1A0C,0.85));c.setLineWidth(2.6)
for x in [107.0,141.0] { c.move(to:CGPoint(x:x,y:139));c.addQuadCurve(to:CGPoint(x:x+12,y:139),control:CGPoint(x:x+6,y:144));c.strokePath() }
c.setStrokeColor(color(0x9A5F38));c.setLineWidth(2.2);c.move(to:CGPoint(x:123,y:158));c.addQuadCurve(to:CGPoint(x:137,y:158),control:CGPoint(x:130,y:164));c.strokePath();c.restoreGState()
let rep=NSBitmapImageRep(cgImage:c.makeImage()!)
try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
