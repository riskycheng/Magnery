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
        print("📸 [EXIF] Starting metadata extraction from URL: \(url.lastPathComponent)")
        
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            print("❌ [EXIF] Failed to create image source from URL")
            return (nil, nil)
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            print("❌ [EXIF] Failed to get image properties from URL")
            return (nil, nil)
        }
        
        print("✅ [EXIF] Got image properties from file")
        print("📋 [EXIF] Available property keys: \(imageProperties.keys.map { $0 as String })")
        
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
            if let error = error {
                print("Reverse geocoding failed: \(error.localizedDescription)")
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
        print("📸 [EXIF] Starting metadata extraction from UIImage...")
        print("📸 [EXIF] Image size: \(image.size)")
        
        guard let imageData = image.jpegData(compressionQuality: 1.0) ?? image.pngData() else {
            print("❌ [EXIF] Failed to get image data")
            return (nil, nil)
        }
        
        print("✅ [EXIF] Got image data, size: \(imageData.count) bytes")
        
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            print("❌ [EXIF] Failed to create image source")
            return (nil, nil)
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            print("❌ [EXIF] Failed to get image properties")
            return (nil, nil)
        }
        
        print("✅ [EXIF] Got image properties")
        print("📋 [EXIF] Available property keys: \(imageProperties.keys.map { $0 as String })")
        
        return extractMetadataFromProperties(imageProperties)
    }
    
    // Common extraction logic from image properties dictionary
    private static func extractMetadataFromProperties(_ imageProperties: [CFString: Any]) -> (date: Date?, coordinates: CLLocationCoordinate2D?) {
        var date: Date?
        var coordinates: CLLocationCoordinate2D?
        
        // Extract date
        if let exifDict = imageProperties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            print("📅 [EXIF] Found EXIF dictionary with keys: \(exifDict.keys.map { $0 as String })")
            
            if let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal] as? String {
                print("📅 [EXIF] Found DateTimeOriginal: \(dateString)")
                date = parseDateFromEXIF(dateString)
                if let parsedDate = date {
                    print("✅ [EXIF] Successfully parsed date: \(parsedDate)")
                } else {
                    print("❌ [EXIF] Failed to parse DateTimeOriginal")
                }
            } else if let dateString = exifDict[kCGImagePropertyExifDateTimeDigitized] as? String {
                print("📅 [EXIF] Found DateTimeDigitized: \(dateString)")
                date = parseDateFromEXIF(dateString)
                if let parsedDate = date {
                    print("✅ [EXIF] Successfully parsed date: \(parsedDate)")
                } else {
                    print("❌ [EXIF] Failed to parse DateTimeDigitized")
                }
            } else {
                print("⚠️ [EXIF] No date found in EXIF dictionary")
            }
        } else {
            print("⚠️ [EXIF] No EXIF dictionary found")
        }
        
        if date == nil,
           let tiffDict = imageProperties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            print("📅 [EXIF] Trying TIFF dictionary with keys: \(tiffDict.keys.map { $0 as String })")
            if let dateString = tiffDict[kCGImagePropertyTIFFDateTime] as? String {
                print("📅 [EXIF] Found TIFF DateTime: \(dateString)")
                date = parseDateFromEXIF(dateString)
                if let parsedDate = date {
                    print("✅ [EXIF] Successfully parsed TIFF date: \(parsedDate)")
                } else {
                    print("❌ [EXIF] Failed to parse TIFF DateTime")
                }
            } else {
                print("⚠️ [EXIF] No DateTime found in TIFF dictionary")
            }
        }
        
        // Extract GPS coordinates
        if let gpsDict = imageProperties[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            print("📍 [EXIF] Found GPS dictionary with keys: \(gpsDict.keys.map { $0 as String })")
            
            if let latitudeValue = gpsDict[kCGImagePropertyGPSLatitude] as? Double,
               let latitudeRef = gpsDict[kCGImagePropertyGPSLatitudeRef] as? String,
               let longitudeValue = gpsDict[kCGImagePropertyGPSLongitude] as? Double,
               let longitudeRef = gpsDict[kCGImagePropertyGPSLongitudeRef] as? String {
                
                let latitude = latitudeRef == "S" ? -latitudeValue : latitudeValue
                let longitude = longitudeRef == "W" ? -longitudeValue : longitudeValue
                
                print("📍 [EXIF] Latitude: \(latitude) (\(latitudeRef))")
                print("📍 [EXIF] Longitude: \(longitude) (\(longitudeRef))")
                
                coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                print("✅ [EXIF] Successfully extracted coordinates: \(latitude), \(longitude)")
            } else {
                print("⚠️ [EXIF] GPS data incomplete")
                print("   Latitude: \(gpsDict[kCGImagePropertyGPSLatitude] as? Double ?? -1)")
                print("   LatitudeRef: \(gpsDict[kCGImagePropertyGPSLatitudeRef] as? String ?? "nil")")
                print("   Longitude: \(gpsDict[kCGImagePropertyGPSLongitude] as? Double ?? -1)")
                print("   LongitudeRef: \(gpsDict[kCGImagePropertyGPSLongitudeRef] as? String ?? "nil")")
            }
        } else {
            print("⚠️ [EXIF] No GPS dictionary found")
        }
        
        print("📸 [EXIF] Extraction complete - Date: \(date?.description ?? "nil"), Coordinates: \(coordinates?.latitude ?? 0), \(coordinates?.longitude ?? 0)")
        
        return (date, coordinates)
    }
}

