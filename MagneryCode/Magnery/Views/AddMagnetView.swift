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
    @State private var isGeneratingNotes = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ZStack {
                        Ellipse()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.95, blue: 0.65).opacity(0.6),
                                        Color(red: 1.0, green: 0.92, blue: 0.7).opacity(0.4),
                                        Color(red: 0.98, green: 0.95, blue: 0.85).opacity(0.2),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 60,
                                    endRadius: 200
                                )
                            )
                            .frame(width: 380, height: 420)
                            .blur(radius: 35)
                        
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    }
                    .padding(.top, 30)
                    
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                            
                            TextField("取个名字", text: $name)
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 20)
                        }
                        .frame(width: 320, height: 52)
                        
                        ZStack(alignment: .bottomTrailing) {
                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                                
                                TextEditor(text: $notes)
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(.primary)
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 110)
                                    .padding(16)
                                    .padding(.bottom, 44)
                                
                                if notes.isEmpty {
                                    Text("添加一点描述...")
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundColor(.gray.opacity(0.4))
                                        .padding(.top, 24)
                                        .padding(.leading, 20)
                                        .allowsHitTesting(false)
                                }
                            }
                            
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                generateNotes()
                            }) {
                                ZStack {
                                    if isGeneratingNotes {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .tint(.orange)
                                    } else {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.orange)
                                    }
                                }
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Color.orange.opacity(0.1))
                                )
                            }
                            .disabled(name.isEmpty || isGeneratingNotes)
                            .opacity(name.isEmpty ? 0.3 : 1.0)
                            .padding(12)
                        }
                        .frame(width: 320, height: 110)
                    }
                    
                    Spacer(minLength: 180)
                }
            
                
                VStack {
                    Spacer()
                    
                    HStack(spacing: 44) {
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            processImage()
                        }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.orange.opacity(0.6), Color.orange.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2.5
                                        )
                                )
                                .overlay(
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(Color.orange.opacity(0.9))
                                )
                                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                        }
                        
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            saveMagnet()
                        }) {
                            ZStack {
                                if name.isEmpty {
                                    Circle()
                                        .fill(Color.gray.opacity(0.25))
                                        .frame(width: 82, height: 82)
                                } else {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(red: 0.3, green: 0.8, blue: 0.5), Color(red: 0.2, green: 0.7, blue: 0.4)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 82, height: 82)
                                }
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .shadow(color: name.isEmpty ? .clear : Color(red: 0.2, green: 0.7, blue: 0.4).opacity(0.35), radius: 14, x: 0, y: 6)
                        }
                        .disabled(name.isEmpty)
                        
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            dismiss()
                        }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.25), lineWidth: 2.5)
                                )
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(Color.gray.opacity(0.7))
                                )
                                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 44)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color(UIColor.systemGroupedBackground).opacity(0.85),
                                Color(UIColor.systemGroupedBackground)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 220)
                        .ignoresSafeArea()
                    )
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .onAppear {
                getCurrentLocation()
            }
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
        guard !name.isEmpty else { return }
        
        guard let imagePath = ImageManager.shared.saveImage(image) else {
            return
        }
        
        let magnet = MagnetItem(
            name: name,
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
    
    private func generateNotes() {
        guard !name.isEmpty else { return }
        
        isGeneratingNotes = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let templates = [
                "这是我收藏的\(name)，它有着独特的设计和精致的细节。",
                "\(name)是我最喜欢的收藏之一，每次看到它都会想起美好的回忆。",
                "这个\(name)来自\(location)，它承载着特殊的意义。",
                "\(name)的造型很有特色，是我珍贵的收藏品。",
                "收藏的\(name)，记录了一段难忘的时光。"
            ]
            
            self.notes = templates.randomElement() ?? templates[0]
            self.isGeneratingNotes = false
            
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
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
