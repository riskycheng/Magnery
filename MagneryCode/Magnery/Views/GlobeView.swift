import SwiftUI
import MapKit

struct GlobeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: MagnetStore
    
    // Use MapKit's flyover or standard map with a very high altitude to simulate globe
    // Note: iOS 16+ MapKit supports .mapStyle(.flyover) or .mapStyle(.hybrid)
    // For a true 3D globe, we use MKMapRect.world or a specific camera
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
        span: MKCoordinateSpan(latitudeDelta: 90, longitudeDelta: 180)
    )
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // In iOS 16+, we can use Map(initialPosition:) but for compatibility with existing code:
            Map(coordinateRegion: $region, 
                interactionModes: .all,
                annotationItems: locationClusters) { cluster in
                MapAnnotation(coordinate: cluster.coordinate) {
                    GlobeMarker(cluster: cluster)
                }
            }
            .ignoresSafeArea()
            // Set map type to hybrid/satellite for "Google Earth" feel if available
            // This requires MKMapView which we'd need a UIViewRepresentable for, 
            // but we can stick to SwiftUI Map for now.
            
            // Close button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .shadow(radius: 4)
            }
            .padding(.top, 60)
            .padding(.leading, 20)
            
            VStack {
                Spacer()
                Text("3D 探索模式")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Capsule())
                    .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var locationClusters: [LocationCluster] {
        let validMagnets = store.magnets.filter { $0.hasValidCoordinates }
        let grouped = Dictionary(grouping: validMagnets) { $0.location }
        
        return grouped.compactMap { (location, magnets) -> LocationCluster? in
            guard let first = magnets.first, let lat = first.latitude, let lon = first.longitude else { return nil }
            return LocationCluster(
                id: location,
                location: location,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                magnets: magnets
            )
        }
    }
}

struct GlobeMarker: View {
    let cluster: LocationCluster
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 2)
            
            if cluster.magnets.count > 1 {
                Text("\(cluster.magnets.count)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: 8, y: -8)
            }
        }
    }
}
