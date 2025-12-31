import UIKit
import SwiftUI

enum ShareTemplate: String, CaseIterable {
    case classic = "经典"
    case polaroid = "拍立得"
    case gallery = "画廊"
    case blueprint = "蓝图"
    case minimal = "极简"
    case traveler = "旅人"
    case modern = "现代"
    
    var backgroundColor: UIColor {
        switch self {
        case .classic: return .white
        case .polaroid: return UIColor(red: 0.98, green: 0.98, blue: 0.96, alpha: 1.0)
        case .gallery: return UIColor(red: 0.92, green: 0.90, blue: 0.88, alpha: 1.0)
        case .blueprint: return UIColor(red: 0.0, green: 0.3, blue: 0.6, alpha: 1.0)
        case .minimal: return .white
        case .traveler: return UIColor(red: 0.94, green: 0.92, blue: 0.88, alpha: 1.0)
        case .modern: return .white // Will be covered by gradient
        }
    }
    
    var textColor: UIColor {
        switch self {
        case .classic: return .black
        case .polaroid: return UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1.0)
        case .gallery: return UIColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1.0)
        case .blueprint: return .white
        case .minimal: return .black
        case .traveler: return UIColor(red: 0.3, green: 0.25, blue: 0.2, alpha: 1.0)
        case .modern: return .white
        }
    }
    
    enum Layout {
        case vertical, horizontal, polaroid, overlay, blueprint
    }
    
    var layout: Layout {
        switch self {
        case .classic, .minimal, .traveler, .gallery: return .vertical
        case .polaroid: return .polaroid
        case .modern: return .overlay
        case .blueprint: return .blueprint
        }
    }
}

class ShareImageHelper {
    static func generateShareImage(for image: UIImage, item: MagnetItem, template: ShareTemplate = .classic) -> UIImage? {
        let canvasSize: CGSize
        let padding: CGFloat = 60
        
        // Determine Canvas Size based on layout
        switch template.layout {
        case .vertical:
            canvasSize = CGSize(width: image.size.width + padding * 2, height: image.size.height + padding * 3 + 200)
        case .horizontal:
            canvasSize = CGSize(width: image.size.width + 400 + padding * 3, height: image.size.height + padding * 2)
        case .polaroid:
            let side = max(image.size.width, image.size.height) + padding * 2
            canvasSize = CGSize(width: side, height: side + 180)
        case .overlay, .blueprint:
            canvasSize = image.size
        }
        
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // 1. Draw Background
        let rect = CGRect(origin: .zero, size: canvasSize)
        if template == .modern {
            drawGradientBackground(in: rect, context: context)
        } else {
            template.backgroundColor.setFill()
            context.fill(rect)
        }
        
        // 2. Draw Image and Text based on layout
        switch template.layout {
        case .vertical:
            drawVerticalLayout(image: image, item: item, template: template, canvasSize: canvasSize, padding: padding, context: context)
        case .horizontal:
            drawHorizontalLayout(image: image, item: item, template: template, canvasSize: canvasSize, padding: padding, context: context)
        case .polaroid:
            drawPolaroidLayout(image: image, item: item, template: template, canvasSize: canvasSize, padding: padding, context: context)
        case .overlay:
            drawOverlayLayout(image: image, item: item, template: template, canvasSize: canvasSize, context: context)
        case .blueprint:
            drawBlueprintLayout(image: image, item: item, template: template, canvasSize: canvasSize, context: context)
        }
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return finalImage
    }
    
    private static func drawGradientBackground(in rect: CGRect, context: CGContext) {
        let colors = [
            UIColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1.0).cgColor,
            UIColor(red: 1.0, green: 0.2, blue: 0.6, alpha: 1.0).cgColor
        ]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: rect.width, y: rect.height), options: [])
    }
    
    private static func drawVerticalLayout(image: UIImage, item: MagnetItem, template: ShareTemplate, canvasSize: CGSize, padding: CGFloat, context: CGContext) {
        let imageRect = CGRect(x: padding, y: padding, width: image.size.width, height: image.size.height)
        
        // Gallery Frame
        if template == .gallery {
            context.saveGState()
            let frameRect = imageRect.insetBy(dx: -20, dy: -20)
            UIColor.white.setFill()
            context.fill(frameRect)
            context.setShadow(offset: CGSize(width: 0, height: 10), blur: 20, color: UIColor.black.withAlphaComponent(0.2).cgColor)
            context.setStrokeColor(UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0).cgColor)
            context.setLineWidth(10)
            context.stroke(frameRect)
            context.restoreGState()
        }
        
        // Shadow
        if template != .minimal && template != .gallery {
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 15), blur: 30, color: UIColor.black.withAlphaComponent(0.1).cgColor)
            let path = UIBezierPath(roundedRect: imageRect, cornerRadius: 20)
            context.addPath(path.cgPath)
            context.fillPath()
            context.restoreGState()
        }
        
        // Draw Image
        let path = UIBezierPath(roundedRect: imageRect, cornerRadius: template == .gallery ? 0 : 20)
        context.saveGState()
        context.addPath(path.cgPath)
        context.clip()
        image.draw(in: imageRect)
        context.restoreGState()
        
        // Text
        let textY = imageRect.maxY + 40
        let titleFont = template == .traveler ? UIFont(name: "AmericanTypewriter-Bold", size: 48) ?? UIFont.systemFont(ofSize: 48, weight: .bold) : UIFont.systemFont(ofSize: 48, weight: .bold)
        let detailFont = template == .traveler ? UIFont(name: "AmericanTypewriter", size: 24) ?? UIFont.systemFont(ofSize: 24, weight: .medium) : UIFont.systemFont(ofSize: 24, weight: .medium)
        
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: template.textColor]
        let detailAttrs: [NSAttributedString.Key: Any] = [.font: detailFont, .foregroundColor: template.textColor.withAlphaComponent(0.6)]
        
        item.name.draw(at: CGPoint(x: padding, y: textY), withAttributes: titleAttrs)
        
        let dateStr = formatDate(item.date)
        var infoStr = "\(item.location)  •  \(dateStr)"
        
        if template == .traveler, let lat = item.latitude, let lon = item.longitude {
            let coordStr = String(format: "%.4f°, %.4f°", lat, lon)
            infoStr += "\n\(coordStr)"
        }
        
        infoStr.draw(in: CGRect(x: padding, y: textY + 70, width: canvasSize.width - padding * 2, height: 100), withAttributes: detailAttrs)
        
        // Traveler Stamp
        if template == .traveler {
            drawTravelerStamp(canvasSize: canvasSize, padding: padding, color: template.textColor, context: context)
        }
        
        // Watermark
        drawWatermark(canvasSize: canvasSize, padding: padding, color: template.textColor)
    }
    
    private static func drawBlueprintLayout(image: UIImage, item: MagnetItem, template: ShareTemplate, canvasSize: CGSize, context: CGContext) {
        // Draw Image with white outline
        let padding: CGFloat = 100
        let imageRect = CGRect(x: padding, y: padding, width: canvasSize.width - padding * 2, height: canvasSize.height - padding * 3)
        
        context.saveGState()
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(2)
        context.stroke(imageRect)
        
        // Draw grid lines
        let step: CGFloat = 100
        for x in stride(from: 0, to: canvasSize.width, by: step) {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: canvasSize.height))
        }
        for y in stride(from: 0, to: canvasSize.height, by: step) {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: canvasSize.width, y: y))
        }
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.1).cgColor)
        context.strokePath()
        context.restoreGState()
        
        image.draw(in: imageRect)
        
        // Technical Text
        let font = UIFont(name: "Courier-Bold", size: 32) ?? UIFont.monospacedSystemFont(ofSize: 32, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
        
        let info = "PROJECT: \(item.name.uppercased())\nLOC: \(item.location.uppercased())\nDATE: \(formatDate(item.date))"
        info.draw(at: CGPoint(x: padding, y: imageRect.maxY + 40), withAttributes: attrs)
        
        drawWatermark(canvasSize: canvasSize, padding: padding, color: .white)
    }
    
    private static func drawTravelerStamp(canvasSize: CGSize, padding: CGFloat, color: UIColor, context: CGContext) {
        context.saveGState()
        let stampRect = CGRect(x: padding, y: canvasSize.height - padding - 120, width: 120, height: 120)
        context.translateBy(x: stampRect.midX, y: stampRect.midY)
        context.rotate(by: -0.2)
        
        let circlePath = UIBezierPath(ovalIn: CGRect(x: -50, y: -50, width: 100, height: 100))
        color.withAlphaComponent(0.2).setStroke()
        circlePath.lineWidth = 3
        circlePath.stroke()
        
        let stampText = "PASSED"
        let stampFont = UIFont.systemFont(ofSize: 18, weight: .black)
        let stampAttrs: [NSAttributedString.Key: Any] = [.font: stampFont, .foregroundColor: color.withAlphaComponent(0.2)]
        let stampSize = stampText.size(withAttributes: stampAttrs)
        stampText.draw(at: CGPoint(x: -stampSize.width/2, y: -stampSize.height/2), withAttributes: stampAttrs)
        
        context.restoreGState()
    }
    
    private static func drawHorizontalLayout(image: UIImage, item: MagnetItem, template: ShareTemplate, canvasSize: CGSize, padding: CGFloat, context: CGContext) {
        let imageRect = CGRect(x: padding, y: padding, width: image.size.width, height: image.size.height)
        image.draw(in: imageRect)
        
        let textX = imageRect.maxX + 60
        let titleFont = UIFont.systemFont(ofSize: 56, weight: .black)
        let detailFont = UIFont.systemFont(ofSize: 28, weight: .light)
        
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: template.textColor]
        let detailAttrs: [NSAttributedString.Key: Any] = [.font: detailFont, .foregroundColor: template.textColor.withAlphaComponent(0.8)]
        
        let nameRect = CGRect(x: textX, y: padding + 40, width: 300, height: 400)
        item.name.draw(in: nameRect, withAttributes: titleAttrs)
        
        let locationStr = item.location.uppercased()
        locationStr.draw(at: CGPoint(x: textX, y: canvasSize.height - padding - 100), withAttributes: detailAttrs)
        
        let dateStr = formatDate(item.date)
        dateStr.draw(at: CGPoint(x: textX, y: canvasSize.height - padding - 60), withAttributes: detailAttrs)
    }
    
    private static func drawPolaroidLayout(image: UIImage, item: MagnetItem, template: ShareTemplate, canvasSize: CGSize, padding: CGFloat, context: CGContext) {
        let imageSide = canvasSize.width - padding * 2
        let imageRect = CGRect(x: padding, y: padding, width: imageSide, height: imageSide)
        
        // Image with slight inner shadow
        image.draw(in: imageRect)
        
        // Handwritten text
        let font = UIFont(name: "ChalkboardSE-Regular", size: 40) ?? UIFont.systemFont(ofSize: 40)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: template.textColor]
        
        let textY = imageRect.maxY + 40
        item.name.draw(at: CGPoint(x: padding + 20, y: textY), withAttributes: attrs)
        
        let dateStr = formatDate(item.date)
        let dateAttrs: [NSAttributedString.Key: Any] = [.font: font.withSize(24), .foregroundColor: template.textColor.withAlphaComponent(0.5)]
        dateStr.draw(at: CGPoint(x: canvasSize.width - padding - 150, y: textY + 10), withAttributes: dateAttrs)
    }
    
    private static func drawOverlayLayout(image: UIImage, item: MagnetItem, template: ShareTemplate, canvasSize: CGSize, context: CGContext) {
        image.draw(in: CGRect(origin: .zero, size: canvasSize))
        
        // Gradient overlay for text readability
        let colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.6).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: canvasSize.height * 0.6), end: CGPoint(x: 0, y: canvasSize.height), options: [])
        
        let padding: CGFloat = 60
        let titleFont = UIFont.systemFont(ofSize: 72, weight: .black)
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.white]
        
        item.name.draw(at: CGPoint(x: padding, y: canvasSize.height - padding - 120), withAttributes: titleAttrs)
        
        let detailFont = UIFont.systemFont(ofSize: 32, weight: .medium)
        let detailAttrs: [NSAttributedString.Key: Any] = [.font: detailFont, .foregroundColor: UIColor.white.withAlphaComponent(0.8)]
        let infoStr = "\(item.location)  |  \(formatDate(item.date))"
        infoStr.draw(at: CGPoint(x: padding, y: canvasSize.height - padding - 40), withAttributes: detailAttrs)
    }
    
    private static func drawWatermark(canvasSize: CGSize, padding: CGFloat, color: UIColor) {
        let brandFont = UIFont.systemFont(ofSize: 24, weight: .black)
        let brandAttrs: [NSAttributedString.Key: Any] = [.font: brandFont, .foregroundColor: color.withAlphaComponent(0.3), .kern: 4.0]
        let brandName = "MAGNERY"
        let brandSize = brandName.size(withAttributes: brandAttrs)
        brandName.draw(at: CGPoint(x: canvasSize.width - padding - brandSize.width, y: canvasSize.height - padding - 30), withAttributes: brandAttrs)
    }
    
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}

