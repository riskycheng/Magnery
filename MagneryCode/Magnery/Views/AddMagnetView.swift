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
                            Text(name.isEmpty ? "Action Figure" : name)
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Button(action: {}) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            Button(action: {
                                processImage()
                            }) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "arrow.clockwise")
                                            .font(.title2)
                                            .foregroundColor(.black)
                                    )
                                    .shadow(radius: 2)
                            }
                            
                            Button(action: {
                                saveMagnet()
                            }) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.title2)
                                            .foregroundColor(.black)
                                    )
                                    .shadow(radius: 2)
                            }
                            
                            Button(action: {
                                dismiss()
                            }) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "xmark")
                                            .font(.title2)
                                            .foregroundColor(.black)
                                    )
                                    .shadow(radius: 2)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "pencil")
                                    .foregroundColor(.orange)
                                Text("和你知道的物品名称不一样？点击调整")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            TextField("输入物品名称", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.horizontal)
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
