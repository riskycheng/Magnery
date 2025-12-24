import SwiftUI
import MapKit

struct GlobeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: MagnetStore
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
        span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)
    )
    @State private var selectedLocation: LocationCluster?
    @State private var locationManager = CLLocationManager()
    
    var body: some View {
        ZStack(alignment: .top) {
            GlobeMapRepresentable(region: $region, selectedLocation: $selectedLocation, locationClusters: locationClusters)
                .ignoresSafeArea()
            
            // Close button
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .shadow(radius: 4)
                }
                .padding(.top, 10)
                .padding(.leading, 20)
                Spacer()
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
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            VStack {
                if selectedLocation == nil {
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
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            centerOnUserLocation()
        }
    }
    
    private func centerOnUserLocation() {
        locationManager.requestWhenInUseAuthorization()
        if let location = locationManager.location {
            withAnimation {
                region.center = location.coordinate
            }
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

struct GlobeMapRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var selectedLocation: LocationCluster?
    let locationClusters: [LocationCluster]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // Set to Flyover for 3D Globe effect
        mapView.mapType = .hybridFlyover
        
        // Enable 3D features
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        
        // Set initial camera for a "Globe" look
        let camera = MKMapCamera(lookingAtCenter: region.center, fromDistance: 10000000, pitch: 0, heading: 0)
        mapView.setCamera(camera, animated: false)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Update annotations if they changed
        let currentAnnotations = uiView.annotations.compactMap { $0 as? ClusterAnnotation }
        
        if currentAnnotations.count != locationClusters.count {
            uiView.removeAnnotations(uiView.annotations)
            let annotations = locationClusters.map { cluster -> ClusterAnnotation in
                let annotation = ClusterAnnotation()
                annotation.coordinate = cluster.coordinate
                annotation.cluster = cluster
                return annotation
            }
            uiView.addAnnotations(annotations)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: GlobeMapRepresentable
        
        init(_ parent: GlobeMapRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation as? ClusterAnnotation, let cluster = annotation.cluster {
                withAnimation {
                    parent.selectedLocation = cluster
                }
                // Deselect so it can be selected again
                mapView.deselectAnnotation(annotation, animated: true)
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let clusterAnnotation = annotation as? ClusterAnnotation else { return nil }
            
            let identifier = "MagnetCluster"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false // We use our own UI
            } else {
                annotationView?.annotation = annotation
            }
            
            if let cluster = clusterAnnotation.cluster {
                // Create a custom view for the annotation
                let size = CGSize(width: 100, height: 100)
                let controller = UIHostingController(rootView: 
                    GlobeMarker(cluster: cluster)
                        .frame(width: size.width, height: size.height)
                )
                controller.view.backgroundColor = .clear
                controller.view.frame = CGRect(origin: .zero, size: size)
                
                // Ensure layout is performed
                controller.view.layoutIfNeeded()
                
                // Convert SwiftUI view to UIImage for the annotation
                let renderer = UIGraphicsImageRenderer(size: size)
                let image = renderer.image { _ in
                    controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
                }
                
                annotationView?.image = image
                annotationView?.centerOffset = CGPoint(x: 0, y: -size.height / 2)
            }
            
            return annotationView
        }
    }
}

class ClusterAnnotation: MKPointAnnotation {
    var cluster: LocationCluster?
}

struct GlobeMarker: View {
    let cluster: LocationCluster
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
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
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                
                if cluster.magnets.count > 1 {
                    Text("\(cluster.magnets.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange))
                        .offset(x: 6, y: -6)
                }
            }
            
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 10))
                .foregroundColor(.white)
                .shadow(radius: 1)
        }
    }
}

