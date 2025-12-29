import UIKit
import SwiftUI

enum ShareTemplate: String, CaseIterable {
    case classic = "经典"
    case studio = "工作室"
    case noir = "暗夜"
    case sand = "流沙"
    case minimal = "极简"
    case vintage = "复古"
    case pop = "波普"
    
    var backgroundColor: UIColor {
        switch self {
        case .classic: return .white
        case .studio: return UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
        case .noir: return UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        case .sand: return UIColor(red: 0.94, green: 0.92, blue: 0.88, alpha: 1.0)
        case .minimal: return .white
        case .vintage: return UIColor(red: 0.88, green: 0.82, blue: 0.75, alpha: 1.0)
        case .pop: return UIColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0) // Bright Yellow
        }
    }
    
    var textColor: UIColor {
        switch self {
        case .classic: return .black
        case .studio: return UIColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1.0)
        case .noir: return UIColor(red: 0.9, green: 0.8, blue: 0.6, alpha: 1.0)
        case .sand: return UIColor(red: 0.3, green: 0.25, blue: 0.2, alpha: 1.0)
        case .minimal: return .black
        case .vintage: return UIColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 1.0)
        case .pop: return UIColor(red: 0.9, green: 0.1, blue: 0.4, alpha: 1.0) // Hot Pink
        }
    }
}

class ShareImageHelper {
    static func generateShareImage(for image: UIImage, magnetName: String, template: ShareTemplate = .classic) -> UIImage? {
        let padding: CGFloat = 80
        let bottomAreaHeight: CGFloat = 180
        let cornerRadius: CGFloat = 40
        
        let canvasWidth = image.size.width + padding * 2
        let canvasHeight = image.size.height + padding * 2 + bottomAreaHeight
        let canvasSize = CGSize(width: canvasWidth, height: canvasHeight)
        
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // 1. Draw Background with subtle gradient for premium feel
        let rect = CGRect(origin: .zero, size: canvasSize)
        template.backgroundColor.setFill()
        context.fill(rect)
        
        // 2. Draw Image with High-End Shadow
        let imageRect = CGRect(x: padding, y: padding, width: image.size.width, height: image.size.height)
        
        context.saveGState()
        if template == .pop {
            // Pop style: Thick black border instead of shadow
            let borderPath = UIBezierPath(roundedRect: imageRect.insetBy(dx: -10, dy: -10), cornerRadius: cornerRadius + 10)
            UIColor.black.setFill()
            borderPath.fill()
        } else if template != .minimal {
            context.setShadow(offset: CGSize(width: 0, height: 20), blur: 40, color: UIColor.black.withAlphaComponent(0.15).cgColor)
        }
        
        let path = UIBezierPath(roundedRect: imageRect, cornerRadius: cornerRadius)
        context.addPath(path.cgPath)
        context.clip()
        image.draw(in: imageRect)
        context.restoreGState()
        
        // 3. Draw Brand Watermark Area
        let titleFont: UIFont
        let brandFont: UIFont
        let detailFont: UIFont
        
        switch template {
        case .minimal:
            titleFont = UIFont.systemFont(ofSize: 44, weight: .light)
            brandFont = UIFont.systemFont(ofSize: 28, weight: .medium)
            detailFont = UIFont.systemFont(ofSize: 20, weight: .light)
        case .vintage:
            titleFont = UIFont(name: "Georgia-Bold", size: 48) ?? UIFont.systemFont(ofSize: 48, weight: .bold)
            brandFont = UIFont(name: "Georgia-Italic", size: 32) ?? UIFont.systemFont(ofSize: 32, weight: .black)
            detailFont = UIFont(name: "Georgia", size: 24) ?? UIFont.systemFont(ofSize: 24, weight: .medium)
        case .pop:
            titleFont = UIFont.systemFont(ofSize: 56, weight: .black)
            brandFont = UIFont.systemFont(ofSize: 40, weight: .black)
            detailFont = UIFont.systemFont(ofSize: 28, weight: .bold)
        default:
            titleFont = UIFont.systemFont(ofSize: 48, weight: .bold)
            brandFont = UIFont.systemFont(ofSize: 32, weight: .black)
            detailFont = UIFont.systemFont(ofSize: 24, weight: .medium)
        }
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: template.textColor,
            .kern: template == .minimal ? 0.5 : 1.2
        ]
        
        let brandAttributes: [NSAttributedString.Key: Any] = [
            .font: brandFont,
            .foregroundColor: template.textColor,
            .kern: template == .pop ? 1.0 : 4.0
        ]
        
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: detailFont,
            .foregroundColor: template.textColor.withAlphaComponent(template == .pop ? 0.8 : 0.4)
        ]
        
        // Draw Magnet Name
        let titleY = imageRect.maxY + 60
        let titleRect = CGRect(x: padding, y: titleY, width: canvasWidth - padding * 2, height: 60)
        magnetName.draw(in: titleRect, withAttributes: titleAttributes)
        
        // Draw Brand Name "MAGNERY"
        let brandName = "MAGNERY"
        let brandSize = brandName.size(withAttributes: brandAttributes)
        let brandX = canvasWidth - padding - brandSize.width
        let brandY = canvasHeight - padding - 40
        brandName.draw(at: CGPoint(x: brandX, y: brandY), withAttributes: brandAttributes)
        
        // Draw "COLLECTED MEMORIES"
        let slogan = "COLLECTED MEMORIES"
        let sloganSize = slogan.size(withAttributes: detailAttributes)
        let sloganX = canvasWidth - padding - sloganSize.width
        let sloganY = brandY - 35
        slogan.draw(at: CGPoint(x: sloganX, y: sloganY), withAttributes: detailAttributes)
        
        // Draw a small decorative line
        context.saveGState()
        template.textColor.withAlphaComponent(0.2).setStroke()
        context.setLineWidth(2)
        context.move(to: CGPoint(x: padding, y: brandY + brandSize.height / 2))
        context.addLine(to: CGPoint(x: padding + 100, y: brandY + brandSize.height / 2))
        context.strokePath()
        context.restoreGState()
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return finalImage
    }
}
