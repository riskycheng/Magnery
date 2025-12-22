import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var store: MagnetStore
    @State private var region: MKCoordinateRegion
    @State private var selectedLocation: LocationCluster?
    @State private var showingGlobe = false
    
    init() {
        // Default to China region
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
            span: MKCoordinateSpan(latitudeDelta: 40.0, longitudeDelta: 40.0)
        ))
    }
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, 
                interactionModes: .all,
                annotationItems: locationClusters) { cluster in
                MapAnnotation(coordinate: cluster.coordinate) {
                    LocationMarker(
                        cluster: cluster,
                        isSelected: selectedLocation?.id == cluster.id,
                        onTap: {
                            withAnimation {
                                selectedLocation = cluster
                            }
                        }
                    )
                }
            }
            .ignoresSafeArea()
            
            // Fullscreen button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showingGlobe = true
                    }) {
                        Image(systemName: "globe.asia.australia.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
                }
            }
            
            // Selected location detail card
            if let selected = selectedLocation {
                VStack {
                    Spacer()
                    LocationDetailCard(cluster: selected) {
                        withAnimation {
                            selectedLocation = nil
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            updateRegion()
        }
        .onChange(of: store.magnets) { _ in
            updateRegion()
        }
        .fullScreenCover(isPresented: $showingGlobe) {
            GlobeView()
        }
    }
    
    private var locationClusters: [LocationCluster] {
        // Group magnets by location
        let validMagnets = store.magnets.filter { $0.hasValidCoordinates }
        let grouped = Dictionary(grouping: validMagnets) { magnet -> String in
            // Group by location name
            return magnet.location
        }
        
        var clusters = grouped.compactMap { (location, magnets) -> LocationCluster? in
            guard let firstMagnet = magnets.first,
                  let lat = firstMagnet.latitude,
                  let lon = firstMagnet.longitude else {
                return nil
            }
            
            return LocationCluster(
                id: location,
                location: location,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                magnets: magnets
            )
        }
        
        // Add jitter to overlapping or very close markers
        for i in 0..<clusters.count {
            for j in (i + 1)..<clusters.count {
                let coord1 = clusters[i].coordinate
                let coord2 = clusters[j].coordinate
                
                let latDiff = abs(coord1.latitude - coord2.latitude)
                let lonDiff = abs(coord1.longitude - coord2.longitude)
                
                // If markers are very close (approx < 500m at equator)
                if latDiff < 0.005 && lonDiff < 0.005 {
                    // Apply a small offset to the second marker
                    let jitterLat = 0.003 * Double.random(in: -1...1)
                    let jitterLon = 0.003 * Double.random(in: -1...1)
                    
                    clusters[j] = LocationCluster(
                        id: clusters[j].id,
                        location: clusters[j].location,
                        coordinate: CLLocationCoordinate2D(
                            latitude: coord2.latitude + jitterLat,
                            longitude: coord2.longitude + jitterLon
                        ),
                        magnets: clusters[j].magnets
                    )
                }
            }
        }
        
        return clusters
    }
    
    private func updateRegion() {
        let validMagnets = store.magnets.filter { $0.hasValidCoordinates }
        guard !validMagnets.isEmpty else { return }
        
        let latitudes = validMagnets.compactMap { $0.latitude }
        let longitudes = validMagnets.compactMap { $0.longitude }
        
        guard !latitudes.isEmpty, !longitudes.isEmpty else { return }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let centerLat = (minLat + maxLat) / 2.0
        let centerLon = (minLon + maxLon) / 2.0
        
        let spanLat = max((maxLat - minLat) * 1.5, 1.0)
        let spanLon = max((maxLon - minLon) * 1.5, 1.0)
        
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
    }
}

// Location cluster model
struct LocationCluster: Identifiable {
    let id: String
    let location: String
    let coordinate: CLLocationCoordinate2D
    let magnets: [MagnetItem]
}

// Map marker view (iOS Photos style)
struct LocationMarker: View {
    let cluster: LocationCluster
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                // Single photo thumbnail (first photo)
                if let firstMagnet = cluster.magnets.first,
                   let image = ImageManager.shared.loadImage(filename: firstMagnet.imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .background(Color.white) // Added white background
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.white, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                
                // Count badge (top-right corner)
                if cluster.magnets.count > 1 {
                    Text("\(cluster.magnets.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 1.0, green: 0.6, blue: 0.2),
                                            Color(red: 1.0, green: 0.5, blue: 0.0)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        )
                        .offset(x: 6, y: -6)
                }
            }
            
            // Location pin
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 10))
                .foregroundColor(isSelected ? Color.orange : Color.white)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                .offset(y: -2)
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .onTapGesture {
            onTap()
        }
    }
}

// Detail card for selected location
struct LocationDetailCard: View {
    let cluster: LocationCluster
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cluster.location)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("\(cluster.magnets.count)个冰箱贴")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            
            // Preview images
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cluster.magnets.prefix(5)) { magnet in
                        if let image = ImageManager.shared.loadImage(filename: magnet.imagePath) {
                            NavigationLink(destination: DetailView(magnet: magnet)) {
                                VStack(spacing: 6) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    
                                    Text(magnet.name)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(width: 80)
                                }
                            }
                        }
                    }
                    
                    if cluster.magnets.count > 5 {
                        VStack {
                            Text("+\(cluster.magnets.count - 5)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.gray)
                            Text("更多")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 80, height: 80)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
    }
}

#Preview {
    MapView()
        .environmentObject(MagnetStore())
}

