import UIKit
import SwiftUI

enum ShareTemplate: String, CaseIterable {
    case pure = "纯净"
    case classic = "经典"
    case polaroid = "拍立得"
    case gallery = "画廊"
    case blueprint = "蓝图"
    case minimal = "极简"
    case traveler = "旅人"
    case modern = "现代"
    case magazine = "杂志"
    case poster = "海报"
    case zen = "禅意"
    case journal = "手账"
    
    var backgroundColor: UIColor {
        switch self {
        case .pure: return .clear
        case .classic: return .white
        case .polaroid: return UIColor(red: 0.99, green: 0.99, blue: 0.98, alpha: 1.0)
        case .gallery: return UIColor(red: 0.94, green: 0.92, blue: 0.90, alpha: 1.0)
        case .blueprint: return UIColor(red: 0.05, green: 0.2, blue: 0.45, alpha: 1.0)
        case .minimal: return .white
        case .traveler: return UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)
        case .modern: return .white
        case .magazine: return .white
        case .poster: return UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0) // Dark Poster
        case .zen: return UIColor(red: 0.98, green: 0.98, blue: 0.96, alpha: 1.0)
        case .journal: return UIColor(red: 1.0, green: 0.99, blue: 0.96, alpha: 1.0)
        }
    }
    
    var textColor: UIColor {
        switch self {
        case .pure: return .black
        case .classic: return UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        case .polaroid: return UIColor(red: 0.25, green: 0.25, blue: 0.35, alpha: 1.0)
        case .gallery: return UIColor(red: 0.25, green: 0.2, blue: 0.15, alpha: 1.0)
        case .blueprint: return UIColor.white.withAlphaComponent(0.9)
        case .minimal: return .black
        case .traveler: return UIColor(red: 0.35, green: 0.3, blue: 0.25, alpha: 1.0)
        case .modern: return .white
        case .magazine: return .black
        case .poster: return UIColor(red: 0.95, green: 0.8, blue: 0.0, alpha: 1.0) // Gold on Dark
        case .zen: return UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        case .journal: return UIColor(red: 0.45, green: 0.35, blue: 0.25, alpha: 1.0)
        }
    }
    
    enum Layout {
        case pure, vertical, horizontal, polaroid, overlay, blueprint, magazine, zen
    }
    
    var layout: Layout {
        switch self {
        case .pure: return .pure
        case .classic, .minimal, .traveler, .gallery, .poster, .journal: return .vertical
        case .polaroid: return .polaroid
        case .modern: return .overlay
        case .blueprint: return .blueprint
        case .magazine: return .magazine
        case .zen: return .zen
        }
    }
}

class ShareImageHelper {
    static func generateShareImage(for image: UIImage, item: MagnetItem, template: ShareTemplate = .classic) -> UIImage? {
        let canvasSize: CGSize
        let padding: CGFloat = 60
        
        // Determine Canvas Size based on layout
        switch template.layout {
        case .pure:
            let side = max(image.size.width, image.size.height)
            canvasSize = CGSize(width: side, height: side)
        case .vertical:
            canvasSize = CGSize(width: image.size.width + padding * 2, height: image.size.height + padding * 3 + 200)
        case .horizontal:
            canvasSize = CGSize(width: image.size.width + 400 + padding * 3, height: image.size.height + padding * 2)
        case .polaroid:
            let side = max(image.size.width, image.size.height) + padding * 2
            canvasSize = CGSize(width: side, height: side + 180)
        case .overlay, .blueprint, .magazine, .zen:
            canvasSize = image.size
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0 // Force 2x scale instead of 3x to save memory while keeping quality
        format.opaque = false
        let mainRenderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        
        return mainRenderer.image { rendererContext in
            let context = rendererContext.cgContext
            
            // 1. Draw Background
            let rect = CGRect(origin: .zero, size: canvasSize)
            if template == .modern {
                drawGradientBackground(in: rect, context: context)
            } else if template != .pure {
                template.backgroundColor.setFill()
                context.fill(rect)
            }
            
            // 2. Draw Image and Text based on layout
            switch template.layout {
            case .pure:
                drawPureLayout(image: image, canvasSize: canvasSize, context: context)
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
            case .magazine:
                drawMagazineLayout(image: image, item: item, template: template, canvasSize: canvasSize, context: context)
            case .zen:
                drawZenLayout(image: image, item: item, template: template, canvasSize: canvasSize, context: context)
            }
        }
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
    
    private static func drawPureLayout(image: UIImage, canvasSize: CGSize, context: CGContext) {
        let side = canvasSize.width
        let imageAspect = image.size.width / image.size.height
        
        let drawRect: CGRect
        if imageAspect > 1 {
            // Wider than tall - Aspect Fit
            let h = side / imageAspect
            drawRect = CGRect(x: 0, y: (side - h) / 2, width: side, height: h)
        } else {
            // Taller than wide - Aspect Fit
            let w = side * imageAspect
            drawRect = CGRect(x: (side - w) / 2, y: 0, width: w, height: side)
        }
        
        context.saveGState()
        // Draw the image directly without clipping to allow transparency to be preserved
        image.draw(in: drawRect)
        context.restoreGState()
    }
    
    private static func drawVerticalLayout(image: UIImage, item: MagnetItem, template: ShareTemplate, canvasSize: CGSize, padding: CGFloat, context: CGContext) {
        let imageRect = CGRect(x: padding, y: padding, width: image.size.width, height: image.size.height)
        
        // Gallery Frame
        if template == .gallery {
            context.saveGState()
            let frameRect = imageRect.insetBy(dx: -30, dy: -30)
            UIColor.white.setFill()
            context.fill(frameRect)
            context.setShadow(offset: CGSize(width: 0, height: 15), blur: 25, color: UIColor.black.withAlphaComponent(0.3).cgColor)
            context.setStrokeColor(UIColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1.0).cgColor)
            context.setLineWidth(15)
            context.stroke(frameRect)
            
            // Inner matting
            let matRect = imageRect.insetBy(dx: -5, dy: -5)
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.1).cgColor)
            context.setLineWidth(1)
            context.stroke(matRect)
            context.restoreGState()
        }
        
        // Poster Border
        if template == .poster {
            context.saveGState()
            let borderRect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: 40, dy: 40)
            template.textColor.withAlphaComponent(0.5).setStroke()
            context.setLineWidth(1)
            context.stroke(borderRect)
            context.restoreGState()
        }
        
        // Shadow
        if template != .minimal && template != .gallery && template != .poster && template != .journal {
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 20), blur: 40, color: UIColor.black.withAlphaComponent(0.15).cgColor)
            let path = UIBezierPath(roundedRect: imageRect, cornerRadius: 24)
            context.addPath(path.cgPath)
            context.fillPath()
            context.restoreGState()
        }
        
        // Draw Image
        let cornerRadius: CGFloat = (template == .gallery || template == .poster) ? 0 : 24
        let path = UIBezierPath(roundedRect: imageRect, cornerRadius: cornerRadius)
        context.saveGState()
        context.addPath(path.cgPath)
        context.clip()
        image.draw(in: imageRect)
        context.restoreGState()
        
        // Text
        let textY = imageRect.maxY + 50
        let titleFont: UIFont
        let detailFont: UIFont
        
        switch template {
        case .classic:
            titleFont = UIFont(name: "Optima-Bold", size: 52) ?? UIFont.systemFont(ofSize: 52, weight: .bold)
            detailFont = UIFont(name: "Optima-Regular", size: 26) ?? UIFont.systemFont(ofSize: 26)
        case .traveler:
            titleFont = UIFont(name: "AmericanTypewriter-Bold", size: 48) ?? UIFont.systemFont(ofSize: 48, weight: .bold)
            detailFont = UIFont(name: "AmericanTypewriter", size: 24) ?? UIFont.systemFont(ofSize: 24, weight: .medium)
        case .poster:
            titleFont = UIFont(name: "AvenirNext-Heavy", size: 84) ?? UIFont.systemFont(ofSize: 84, weight: .black)
            detailFont = UIFont(name: "AvenirNext-Bold", size: 32) ?? UIFont.systemFont(ofSize: 32, weight: .bold)
        case .journal:
            titleFont = UIFont(name: "SnellRoundhand-Bold", size: 68) ?? UIFont.systemFont(ofSize: 68, weight: .bold)
            detailFont = UIFont(name: "SnellRoundhand", size: 34) ?? UIFont.systemFont(ofSize: 34)
        case .minimal:
            titleFont = UIFont.systemFont(ofSize: 44, weight: .light)
            detailFont = UIFont.systemFont(ofSize: 20, weight: .ultraLight)
        default:
            titleFont = UIFont.systemFont(ofSize: 48, weight: .bold)
            detailFont = UIFont.systemFont(ofSize: 24, weight: .medium)
        }
        
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: template.textColor,
            .kern: template == .minimal ? 8.0 : 1.2
        ]
        let detailAttrs: [NSAttributedString.Key: Any] = [
            .font: detailFont,
            .foregroundColor: template.textColor.withAlphaComponent(0.7),
            .kern: 1.0
        ]
        
        if template == .poster {
            let title = item.name.uppercased()
            let titleSize = title.size(withAttributes: titleAttrs)
            title.draw(at: CGPoint(x: (canvasSize.width - titleSize.width)/2, y: textY), withAttributes: titleAttrs)
            
            let dateStr = formatDate(item.date)
            let infoStr = "\(item.location)  /  \(dateStr)"
            let infoSize = infoStr.size(withAttributes: detailAttrs)
            infoStr.draw(at: CGPoint(x: (canvasSize.width - infoSize.width)/2, y: textY + 110), withAttributes: detailAttrs)
        } else if template == .minimal {
            let title = item.name.uppercased()
            let titleSize = title.size(withAttributes: titleAttrs)
            title.draw(at: CGPoint(x: (canvasSize.width - titleSize.width)/2, y: textY), withAttributes: titleAttrs)
            
            let info = formatDate(item.date)
            let infoSize = info.size(withAttributes: detailAttrs)
            info.draw(at: CGPoint(x: (canvasSize.width - infoSize.width)/2, y: textY + 60), withAttributes: detailAttrs)
        } else {
            item.name.draw(at: CGPoint(x: padding, y: textY), withAttributes: titleAttrs)
            
            let dateStr = formatDate(item.date)
            var infoStr = "\(item.location)  •  \(dateStr)"
            
            if template == .traveler, let lat = item.latitude, let lon = item.longitude {
                let coordStr = String(format: "%.4f°, %.4f°", lat, lon)
                infoStr += "\n\(coordStr)"
            }
            
            infoStr.draw(in: CGRect(x: padding, y: textY + 75, width: canvasSize.width - padding * 2, height: 120), withAttributes: detailAttrs)
        }
        
        // Journal "Tape" effect
        if template == .journal {
            drawJournalTape(imageRect: imageRect, context: context)
        }
        
        // Traveler Stamp
        if template == .traveler {
            drawTravelerStamp(canvasSize: canvasSize, padding: padding, color: template.textColor, context: context)
        }
        
        // Watermark
        drawWatermark(canvasSize: canvasSize, padding: padding, color: template.textColor)
    }
    
    private static func drawJournalTape(imageRect: CGRect, context: CGContext) {
        context.saveGState()
        let tapeColor = UIColor(red: 0.9, green: 0.8, blue: 0.6, alpha: 0.6)
        tapeColor.setFill()
        
        // Top left tape
        let tape1 = CGRect(x: imageRect.minX - 20, y: imageRect.minY - 10, width: 100, height: 40)
        context.translateBy(x: tape1.midX, y: tape1.midY)
        context.rotate(by: -0.4)
        context.fill(CGRect(x: -50, y: -20, width: 100, height: 40))
        context.rotate(by: 0.4)
        context.translateBy(x: -tape1.midX, y: -tape1.midY)
        
        // Bottom right tape
        let tape2 = CGRect(x: imageRect.maxX - 80, y: imageRect.maxY - 30, width: 100, height: 40)
        context.translateBy(x: tape2.midX, y: tape2.midY)
        context.rotate(by: -0.4)
        context.fill(CGRect(x: -50, y: -20, width: 100, height: 40))
        context.restoreGState()
    }
    
    private static func drawBlueprintLayout(image: UIImage, item: MagnetItem, template: ShareTemplate, canvasSize: CGSize, context: CGContext) {
        // Draw Image with white outline
        let padding: CGFloat = 100
        let targetRect = CGRect(x: padding, y: padding, width: canvasSize.width - padding * 2, height: canvasSize.height - padding * 3.5)
        
        // Calculate aspect fit rect to avoid deformation
        let imageAspect = image.size.width / image.size.height
        let targetAspect = targetRect.width / targetRect.height
        
        let imageRect: CGRect
        if imageAspect > targetAspect {
            let h = targetRect.width / imageAspect
            imageRect = CGRect(x: targetRect.minX, y: targetRect.minY + (targetRect.height - h) / 2, width: targetRect.width, height: h)
        } else {
            let w = targetRect.height * imageAspect
            imageRect = CGRect(x: targetRect.minX + (targetRect.width - w) / 2, y: targetRect.minY, width: w, height: targetRect.height)
        }
        
        context.saveGState()
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(2)
        context.stroke(targetRect) // Stroke the target area boundary
        
        // Draw grid lines (cleaner, wider grid)
        let step: CGFloat = 150
        for x in stride(from: 0, to: canvasSize.width, by: step) {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: canvasSize.height))
        }
        for y in stride(from: 0, to: canvasSize.height, by: step) {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: canvasSize.width, y: y))
        }
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.1).cgColor)
        context.setLineWidth(1)
        context.strokePath()
        context.restoreGState()
        
        image.draw(in: imageRect)
        
        // Modern Technical Text (Simplified)
        let titleFont = UIFont(name: "Menlo-Bold", size: 44) ?? UIFont.monospacedSystemFont(ofSize: 44, weight: .bold)
        let detailFont = UIFont(name: "Menlo-Regular", size: 24) ?? UIFont.monospacedSystemFont(ofSize: 24, weight: .regular)
        
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.white, .kern: 2.0]
        let detailAttrs: [NSAttributedString.Key: Any] = [.font: detailFont, .foregroundColor: UIColor.white.withAlphaComponent(0.7), .kern: 1.5]
        
        // Draw Name
        let name = item.name.uppercased()
        name.draw(at: CGPoint(x: padding, y: targetRect.maxY + 60), withAttributes: titleAttrs)
        
        // Draw Location and Date (Simplified)
        let info = "\(item.location.uppercased()) // \(formatDate(item.date))"
        info.draw(at: CGPoint(x: padding, y: targetRect.maxY + 120), withAttributes: detailAttrs)
        
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
        
        // Calculate aspect fill rect for the square polaroid area
        let imageAspect = image.size.width / image.size.height
        let drawRect: CGRect
        if imageAspect > 1 {
            let w = imageSide * imageAspect
            drawRect = CGRect(x: padding - (w - imageSide) / 2, y: padding, width: w, height: imageSide)
        } else {
            let h = imageSide / imageAspect
            drawRect = CGRect(x: padding, y: padding - (h - imageSide) / 2, width: imageSide, height: h)
        }
        
        context.saveGState()
        context.addRect(imageRect)
        context.clip()
        image.draw(in: drawRect)
        context.restoreGState()
        
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
    
    private static func drawMagazineLayout(image: UIImage, item: MagnetItem, template: ShareTemplate, canvasSize: CGSize, context: CGContext) {
        // Full bleed image
        image.draw(in: CGRect(origin: .zero, size: canvasSize))
        
        let padding: CGFloat = 80
        
        // Large Serif Title at top
        let titleFont = UIFont(name: "Georgia-BoldItalic", size: 140) ?? UIFont.systemFont(ofSize: 140, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.white,
            .kern: -2.0,
            .shadow: {
                let shadow = NSShadow()
                shadow.shadowBlurRadius = 15
                shadow.shadowColor = UIColor.black.withAlphaComponent(0.4)
                shadow.shadowOffset = CGSize(width: 0, height: 8)
                return shadow
            }()
        ]
        
        let title = item.name.uppercased()
        title.draw(at: CGPoint(x: padding, y: padding), withAttributes: titleAttrs)
        
        // Issue details
        let issueFont = UIFont(name: "AvenirNext-Bold", size: 24) ?? UIFont.systemFont(ofSize: 24, weight: .bold)
        let issueAttrs: [NSAttributedString.Key: Any] = [.font: issueFont, .foregroundColor: UIColor.white, .kern: 4.0]
        "ISSUE NO. 01 / VOL. 2025".draw(at: CGPoint(x: padding + 5, y: padding + 160), withAttributes: issueAttrs)
        
        // Vertical line and details at bottom left
        context.saveGState()
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(6)
        context.move(to: CGPoint(x: padding, y: canvasSize.height - padding - 180))
        context.addLine(to: CGPoint(x: padding, y: canvasSize.height - padding))
        context.strokePath()
        context.restoreGState()
        
        let detailFont = UIFont(name: "AvenirNext-Medium", size: 36) ?? UIFont.systemFont(ofSize: 36)
        let detailAttrs: [NSAttributedString.Key: Any] = [.font: detailFont, .foregroundColor: UIColor.white, .kern: 1.2]
        
        let info = "\(item.location.uppercased())\n\(formatDate(item.date))"
        info.draw(at: CGPoint(x: padding + 40, y: canvasSize.height - padding - 120), withAttributes: detailAttrs)
        
        drawWatermark(canvasSize: canvasSize, padding: padding, color: .white)
    }
    
    private static func drawZenLayout(image: UIImage, item: MagnetItem, template: ShareTemplate, canvasSize: CGSize, context: CGContext) {
        let padding: CGFloat = 120
        let targetRect = CGRect(x: padding, y: padding, width: canvasSize.width - padding * 3.5, height: canvasSize.height - padding * 2)
        
        // Calculate aspect fit rect to avoid deformation
        let imageAspect = image.size.width / image.size.height
        let targetAspect = targetRect.width / targetRect.height
        
        let imageRect: CGRect
        if imageAspect > targetAspect {
            let h = targetRect.width / imageAspect
            imageRect = CGRect(x: targetRect.minX, y: targetRect.minY + (targetRect.height - h) / 2, width: targetRect.width, height: h)
        } else {
            let w = targetRect.height * imageAspect
            imageRect = CGRect(x: targetRect.minX + (targetRect.width - w) / 2, y: targetRect.minY, width: w, height: targetRect.height)
        }
        
        // Draw Image with subtle border
        context.saveGState()
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.05).cgColor)
        context.setLineWidth(1)
        context.stroke(imageRect.insetBy(dx: -1, dy: -1))
        image.draw(in: imageRect)
        context.restoreGState()
        
        // Vertical Text on the right
        let titleFont = UIFont(name: "PingFangSC-Semibold", size: 72) ?? UIFont.systemFont(ofSize: 72, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: template.textColor, .kern: 4.0]
        
        let textX = canvasSize.width - padding - 100
        var currentY = padding + 40
        
        for char in item.name {
            let s = String(char)
            let size = s.size(withAttributes: titleAttrs)
            s.draw(at: CGPoint(x: textX + (100 - size.width)/2, y: currentY), withAttributes: titleAttrs)
            currentY += size.height + 15
        }
        
        // Red Seal (Traditional Chinese Style)
        let sealRect = CGRect(x: textX + 20, y: currentY + 40, width: 60, height: 60)
        UIColor(red: 0.8, green: 0.2, blue: 0.1, alpha: 0.9).setFill()
        context.fill(sealRect)
        
        let sealFont = UIFont.systemFont(ofSize: 24, weight: .bold)
        let sealAttrs: [NSAttributedString.Key: Any] = [.font: sealFont, .foregroundColor: UIColor.white]
        "灵感".draw(at: CGPoint(x: sealRect.minX + 6, y: sealRect.minY + 15), withAttributes: sealAttrs)
        
        // Location and Date at bottom right
        let detailFont = UIFont(name: "PingFangSC-Light", size: 26) ?? UIFont.systemFont(ofSize: 26, weight: .light)
        let detailAttrs: [NSAttributedString.Key: Any] = [.font: detailFont, .foregroundColor: template.textColor.withAlphaComponent(0.5), .kern: 2.0]
        let info = "\(item.location) · \(formatDate(item.date))"
        
        context.saveGState()
        context.translateBy(x: canvasSize.width - padding, y: canvasSize.height - padding)
        context.rotate(by: -.pi / 2)
        info.draw(at: .zero, withAttributes: detailAttrs)
        context.restoreGState()
        
        drawWatermark(canvasSize: canvasSize, padding: padding, color: template.textColor)
    }
    
    private static func drawWatermark(canvasSize: CGSize, padding: CGFloat, color: UIColor) {
        let brandFont = UIFont.systemFont(ofSize: 22, weight: .black)
        let brandAttrs: [NSAttributedString.Key: Any] = [
            .font: brandFont,
            .foregroundColor: color.withAlphaComponent(0.25),
            .kern: 6.0
        ]
        let brandName = "MAGNERY"
        let brandSize = brandName.size(withAttributes: brandAttrs)
        
        // Draw a small decorative line next to watermark
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        color.withAlphaComponent(0.15).setStroke()
        context?.setLineWidth(1)
        let lineX = canvasSize.width - padding - brandSize.width - 40
        context?.move(to: CGPoint(x: lineX, y: canvasSize.height - padding - 18))
        context?.addLine(to: CGPoint(x: lineX + 20, y: canvasSize.height - padding - 18))
        context?.strokePath()
        context?.restoreGState()
        
        brandName.draw(at: CGPoint(x: canvasSize.width - padding - brandSize.width, y: canvasSize.height - padding - 30), withAttributes: brandAttrs)
    }
    
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}

