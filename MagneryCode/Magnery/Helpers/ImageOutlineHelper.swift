import UIKit
import CoreImage

class ImageOutlineHelper {
    static func addPadding(to image: UIImage, amount: CGFloat) -> UIImage? {
        let newSize = CGSize(width: image.size.width + amount * 2, height: image.size.height + amount * 2)
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        image.draw(at: CGPoint(x: amount, y: amount))
        let paddedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return paddedImage
    }

    static func padToSquare(image: UIImage) -> UIImage? {
        let size = image.size
        let maxDim = max(size.width, size.height)
        let newSize = CGSize(width: maxDim, height: maxDim)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        
        let originX = (maxDim - size.width) / 2
        let originY = (maxDim - size.height) / 2
        image.draw(at: CGPoint(x: originX, y: originY))
        
        let paddedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return paddedImage
    }

    static func createOutline(from image: UIImage, lineWidth: CGFloat = 3, offset: CGFloat = 0) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()
        
        // 1. Create a Solid White Mask from Alpha Channel
        let solidMaskParams: [String: Any] = [
            "inputImage": ciImage,
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ]
        
        guard let solidMask = CIFilter(name: "CIColorMatrix", parameters: solidMaskParams)?.outputImage else { return nil }
        
        // 2. Create the "Inner" Edge (Object + Offset)
        var innerMask = solidMask
        if offset > 0 {
            guard let offsetFilter = CIFilter(name: "CIMorphologyMaximum") else { return nil }
            offsetFilter.setValue(solidMask, forKey: kCIInputImageKey)
            offsetFilter.setValue(offset, forKey: kCIInputRadiusKey)
            guard let result = offsetFilter.outputImage else { return nil }
            innerMask = result
        }
        
        // 3. Create the "Outer" Edge (Inner + LineWidth)
        guard let outerFilter = CIFilter(name: "CIMorphologyMaximum") else { return nil }
        outerFilter.setValue(solidMask, forKey: kCIInputImageKey)
        // Dilate the original solid mask by (offset + lineWidth) to get the outer boundary
        outerFilter.setValue(offset + lineWidth, forKey: kCIInputRadiusKey)
        guard let outerMask = outerFilter.outputImage else { return nil }
        
        // 4. Subtract Inner from Outer (Difference)
        guard let diffFilter = CIFilter(name: "CIDifferenceBlendMode") else { return nil }
        diffFilter.setValue(outerMask, forKey: kCIInputImageKey)
        diffFilter.setValue(innerMask, forKey: kCIInputBackgroundImageKey)
        guard let borderMask = diffFilter.outputImage else { return nil }
        
        // 5. Convert Black to Transparent
        guard let maskToAlpha = CIFilter(name: "CIMaskToAlpha") else { return nil }
        maskToAlpha.setValue(borderMask, forKey: kCIInputImageKey)
        guard let alphaMask = maskToAlpha.outputImage else { return nil }
        
        // 6. Fill with White Color
        guard let colorGen = CIFilter(name: "CIConstantColorGenerator") else { return nil }
        colorGen.setValue(CIColor.white, forKey: kCIInputColorKey)
        guard let whiteColor = colorGen.outputImage else { return nil }
        
        guard let compositeFilter = CIFilter(name: "CIBlendWithMask") else { return nil }
        compositeFilter.setValue(whiteColor, forKey: kCIInputImageKey)
        compositeFilter.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
        compositeFilter.setValue(alphaMask, forKey: kCIInputMaskImageKey)
        
        guard let finalOutput = compositeFilter.outputImage else { return nil }
        
        // 7. Convert back to UIImage
        guard let outlineCGImage = context.createCGImage(finalOutput, from: borderMask.extent) else { return nil }
        
        // Note: We return the outline matching the size of the PADDED image
        return UIImage(cgImage: outlineCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}