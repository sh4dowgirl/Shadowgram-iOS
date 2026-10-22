import Foundation
import UIKit
import AppBundle

/// Draws the ghost glyph into `rect` (UIKit coordinates) with the eyes cut out.
private func drawGhost(in rect: CGRect, color: UIColor, context: CGContext) {
    let unit = rect.width / 24.0
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        return CGPoint(x: rect.minX + x * unit, y: rect.minY + y * unit)
    }

    let body = UIBezierPath()
    body.move(to: p(4.5, 21.0))
    body.addLine(to: p(4.5, 10.5))
    body.addArc(withCenter: p(12.0, 10.5), radius: 7.5 * unit, startAngle: CGFloat.pi, endAngle: 0.0, clockwise: true)
    body.addLine(to: p(19.5, 21.0))
    body.addQuadCurve(to: p(16.0, 19.2), controlPoint: p(17.6, 22.6))
    body.addQuadCurve(to: p(12.0, 19.2), controlPoint: p(14.0, 21.4))
    body.addQuadCurve(to: p(8.0, 19.2), controlPoint: p(10.0, 21.4))
    body.addQuadCurve(to: p(4.5, 21.0), controlPoint: p(6.4, 22.6))
    body.close()

    context.setFillColor(color.cgColor)
    body.fill()

    context.setBlendMode(.clear)
    UIBezierPath(ovalIn: CGRect(origin: p(8.2, 8.6), size: CGSize(width: 2.6 * unit, height: 3.6 * unit))).fill()
    UIBezierPath(ovalIn: CGRect(origin: p(13.2, 8.6), size: CGSize(width: 2.6 * unit, height: 3.6 * unit))).fill()
    context.setBlendMode(.normal)
}

/// White ghost sized like the profile's QR code button icon, for the navigation bar.
public func shadowgramGhostNavigationIcon() -> UIImage? {
    let size = UIImage(bundleImageName: "Settings/QrIcon")?.size ?? CGSize(width: 24.0, height: 24.0)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { rendererContext in
        let side = min(size.width, size.height)
        let rect = CGRect(x: (size.width - side) / 2.0, y: (size.height - side) / 2.0, width: side, height: side)
        drawGhost(in: rect, color: .white, context: rendererContext.cgContext)
    }
}

private func drawMoon(in rect: CGRect, color: UIColor, context: CGContext) {
    let unit = rect.width / 24.0
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        return CGPoint(x: rect.minX + x * unit, y: rect.minY + y * unit)
    }

    context.setFillColor(color.cgColor)
    UIBezierPath(arcCenter: p(11.92, 12.0), radius: 8.6 * unit, startAngle: 0.0, endAngle: CGFloat.pi * 2.0, clockwise: true).fill()

    context.setBlendMode(.clear)
    UIBezierPath(arcCenter: p(8.31, 9.74), radius: 6.22 * unit, startAngle: 0.0, endAngle: CGFloat.pi * 2.0, clockwise: true).fill()
    context.setBlendMode(.normal)
}

/// 30x30 settings-row icon: the Shadowgram gradient with a white crescent moon.
public let shadowgramExtraSettingsIcon: UIImage = {
    let size = CGSize(width: 30.0, height: 30.0)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { rendererContext in
        let context = rendererContext.cgContext
        let bounds = CGRect(origin: CGPoint(), size: size)

        context.saveGState()
        UIBezierPath(roundedRect: bounds, cornerRadius: 8.0).addClip()
        let colors: [CGColor] = [UIColor(red: 0x8E / 255.0, green: 0x7B / 255.0, blue: 0xEF / 255.0, alpha: 1.0).cgColor, UIColor(red: 0xAF / 255.0, green: 0xB2 / 255.0, blue: 0xF8 / 255.0, alpha: 1.0).cgColor]
        var locations: [CGFloat] = [0.0, 1.0]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: &locations) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        }
        context.restoreGState()

        context.beginTransparencyLayer(auxiliaryInfo: nil)
        drawMoon(in: CGRect(x: 5.0, y: 5.0, width: 20.0, height: 20.0), color: .white, context: context)
        context.endTransparencyLayer()
    }
}()
