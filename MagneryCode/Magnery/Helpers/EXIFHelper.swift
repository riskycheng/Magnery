import UIKit
import CoreLocation
import ImageIO

struct ImageMetadata {
    var date: Date?
    var location: CLLocation?
    var locationString: String?
}

class EXIFHelper {
    // Extract metadata directly from a file URL (preserves all EXIF data)
    static func extractBasicMetadata(from url: URL) -> (date: Date?, coordinates: CLLocationCoordinate2D?) {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return (nil, nil)
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return (nil, nil)
        }
        
        return extractMetadataFromProperties(imageProperties)
    }
    static func extractMetadata(from image: UIImage) -> ImageMetadata {
        var metadata = ImageMetadata()
        
        // Try to get the image data
        guard let imageData = image.jpegData(compressionQuality: 1.0) ?? image.pngData() else {
            return metadata
        }
        
        // Create image source from data
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return metadata
        }
        
        // Extract date from EXIF
        if let exifDict = imageProperties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            if let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal] as? String {
                metadata.date = parseDateFromEXIF(dateString)
            } else if let dateString = exifDict[kCGImagePropertyExifDateTimeDigitized] as? String {
                metadata.date = parseDateFromEXIF(dateString)
            }
        }
        
        // Fallback to TIFF date if EXIF date not found
        if metadata.date == nil,
           let tiffDict = imageProperties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let dateString = tiffDict[kCGImagePropertyTIFFDateTime] as? String {
            metadata.date = parseDateFromEXIF(dateString)
        }
        
        // Extract GPS location
        if let gpsDict = imageProperties[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            if let latitude = extractCoordinate(from: gpsDict, latitudeKey: kCGImagePropertyGPSLatitude, latitudeRefKey: kCGImagePropertyGPSLatitudeRef),
               let longitude = extractCoordinate(from: gpsDict, longitudeKey: kCGImagePropertyGPSLongitude, longitudeRefKey: kCGImagePropertyGPSLongitudeRef) {
                
                let location = CLLocation(latitude: latitude, longitude: longitude)
                metadata.location = location
                
                // Reverse geocode to get location string
                reverseGeocode(location: location) { locationString in
                    metadata.locationString = locationString
                }
            }
        }
        
        return metadata
    }
    
    private static func parseDateFromEXIF(_ dateString: String) -> Date? {
        // EXIF date format: "yyyy:MM:dd HH:mm:ss"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }
    
    private static func extractCoordinate(from gpsDict: [CFString: Any], latitudeKey: CFString? = nil, latitudeRefKey: CFString? = nil, longitudeKey: CFString? = nil, longitudeRefKey: CFString? = nil) -> Double? {
        
        if let latitudeKey = latitudeKey, let latitudeRefKey = latitudeRefKey {
            // Extract latitude
            guard let latitude = gpsDict[latitudeKey] as? Double,
                  let latitudeRef = gpsDict[latitudeRefKey] as? String else {
                return nil
            }
            return latitudeRef == "S" ? -latitude : latitude
        }
        
        if let longitudeKey = longitudeKey, let longitudeRefKey = longitudeRefKey {
            // Extract longitude
            guard let longitude = gpsDict[longitudeKey] as? Double,
                  let longitudeRef = gpsDict[longitudeRefKey] as? String else {
                return nil
            }
            return longitudeRef == "W" ? -longitude : longitude
        }
        
        return nil
    }
    
    private static func reverseGeocode(location: CLLocation, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if error != nil {
                completion(nil)
                return
            }
            
            if let placemark = placemarks?.first {
                var locationComponents: [String] = []
                
                // Build location string from most specific to least specific
                if let subLocality = placemark.subLocality {
                    locationComponents.append(subLocality)
                }
                if let locality = placemark.locality {
                    locationComponents.append(locality)
                }
                
                if locationComponents.isEmpty {
                    if let administrativeArea = placemark.administrativeArea {
                        locationComponents.append(administrativeArea)
                    }
                    if let country = placemark.country {
                        locationComponents.append(country)
                    }
                }
                
                let locationString = locationComponents.isEmpty ? nil : locationComponents.joined(separator: "")
                completion(locationString)
            } else {
                completion(nil)
            }
        }
    }
    
    // Synchronous version for immediate use (without reverse geocoding)
    static func extractBasicMetadata(from image: UIImage) -> (date: Date?, coordinates: CLLocationCoordinate2D?) {
        guard let imageData = image.jpegData(compressionQuality: 1.0) ?? image.pngData() else {
            return (nil, nil)
        }
        
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return (nil, nil)
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return (nil, nil)
        }
        
        return extractMetadataFromProperties(imageProperties)
    }
    
    // Common extraction logic from image properties dictionary
    private static func extractMetadataFromProperties(_ imageProperties: [CFString: Any]) -> (date: Date?, coordinates: CLLocationCoordinate2D?) {
        var date: Date?
        var coordinates: CLLocationCoordinate2D?
        
        // Extract date
        if let exifDict = imageProperties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            if let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal] as? String {
                date = parseDateFromEXIF(dateString)
            } else if let dateString = exifDict[kCGImagePropertyExifDateTimeDigitized] as? String {
                date = parseDateFromEXIF(dateString)
            }
        }
        
        if date == nil,
           let tiffDict = imageProperties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            if let dateString = tiffDict[kCGImagePropertyTIFFDateTime] as? String {
                date = parseDateFromEXIF(dateString)
            }
        }
        
        // Extract GPS coordinates
        if let gpsDict = imageProperties[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            if let latitudeValue = gpsDict[kCGImagePropertyGPSLatitude] as? Double,
               let latitudeRef = gpsDict[kCGImagePropertyGPSLatitudeRef] as? String,
               let longitudeValue = gpsDict[kCGImagePropertyGPSLongitude] as? Double,
               let longitudeRef = gpsDict[kCGImagePropertyGPSLongitudeRef] as? String {
                
                let latitude = latitudeRef == "S" ? -latitudeValue : latitudeValue
                let longitude = longitudeRef == "W" ? -longitudeValue : longitudeValue
                
                coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
        }
        
        return (date, coordinates)
    }
}

