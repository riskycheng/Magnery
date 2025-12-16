import SwiftUI
import CoreLocation

struct AddMagnetView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: MagnetStore
    
    let image: UIImage
    @State private var name: String = ""
    @State private var location: String = "未知位置"
    @State private var notes: String = ""
    @State private var isGettingLocation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text(dateString)
                        .font(.title2)
                        .fontWeight(.medium)
                        .padding(.top, 20)
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .shadow(radius: 5)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        HStack {
                            TextField("取个名字", text: $name)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 200)
                            
                            Button(action: {}) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 30) {
                            Button(action: {
                                processImage()
                            }) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 24))
                                            .foregroundColor(Color.orange)
                                    )
                                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                            }
                            
                            Button(action: {
                                saveMagnet()
                            }) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundColor(Color.green)
                                    )
                                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            }
                            
                            Button(action: {
                                dismiss()
                            }) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        Image(systemName: "xmark")
                                            .font(.system(size: 24))
                                            .foregroundColor(Color.gray)
                                    )
                                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .onAppear {
            getCurrentLocation()
        }
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月 d日"
        return formatter.string(from: Date())
    }
    
    private func processImage() {
        dismiss()
    }
    
    private func saveMagnet() {
        guard let imagePath = ImageManager.shared.saveImage(image) else {
            return
        }
        
        let magnet = MagnetItem(
            name: name.isEmpty ? "Action Figure" : name,
            date: Date(),
            location: location,
            imagePath: imagePath,
            notes: notes
        )
        
        store.addMagnet(magnet)
        
        dismiss()
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.dismiss(animated: true)
        }
    }
    
    private func getCurrentLocation() {
        isGettingLocation = true
        let locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
        
        if let currentLocation = locationManager.location {
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(currentLocation) { placemarks, error in
                if let placemark = placemarks?.first {
                    if let city = placemark.locality, let district = placemark.subLocality {
                        location = "\(city)\(district)"
                    } else if let city = placemark.locality {
                        location = city
                    }
                }
                isGettingLocation = false
            }
        } else {
            isGettingLocation = false
        }
    }
}

#Preview {
    AddMagnetView(image: UIImage(systemName: "photo")!)
        .environmentObject(MagnetStore())
}
