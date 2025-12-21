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
    @State private var showingInputDialog = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name
        case notes
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background with Dotted Pattern (matching reference)
                DottedBackgroundView()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Date Header
                    HStack {
                        Text(dateString)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Magnet Image with Glow
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 260, height: 260)
                            .blur(radius: 40)
                        
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 240)
                            .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                    }
                    .padding(.bottom, 40)
                    
                    // Input Trigger (The "Input Box" that calls the dialog)
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showingInputDialog = true
                            focusedField = .name
                        }
                    }) {
                        HStack {
                            Text(name.isEmpty ? "点击输入名称..." : name)
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(name.isEmpty ? .gray.opacity(0.5) : .primary)
                            Spacer()
                            Image(systemName: "pencil")
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .padding(.horizontal, 20)
                        .frame(width: 280, height: 56)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    }
                    .padding(.bottom, 20)
                    
                    Spacer()
                }
                
                // Centered Input Dialog (Conditional)
                if showingInputDialog {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                showingInputDialog = false
                                focusedField = nil
                            }
                        }
                    
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 24) {
                            Text("输入对象名称")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                            
                            VStack(spacing: 12) {
                                TextField("玩偶", text: $name)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .focused($focusedField, equals: .name)
                                    .submitLabel(.next)
                                
                                if focusedField == .notes || !notes.isEmpty {
                                    TextEditor(text: $notes)
                                        .font(.system(size: 16, design: .rounded))
                                        .frame(height: 80)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.05))
                                        .cornerRadius(12)
                                        .focused($focusedField, equals: .notes)
                                } else {
                                    Button(action: { focusedField = .notes }) {
                                        Text(notes.isEmpty ? "添加描述 (可选)" : notes)
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            
                            VStack(spacing: 16) {
                                Button(action: {
                                    saveMagnet()
                                }) {
                                    Text("保存")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(name.isEmpty ? Color.gray : Color.gray.opacity(0.8))
                                        .cornerRadius(28)
                                }
                                .disabled(name.isEmpty)
                                
                                Button(action: {
                                    withAnimation {
                                        showingInputDialog = false
                                        focusedField = nil
                                    }
                                }) {
                                    Text("取消")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 32)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                        )
                        .padding(.horizontal, 40)
                        
                        if focusedField == nil {
                            Spacer()
                        } else {
                            // This small frame ensures the dialog sits right above the keyboard
                            Color.clear.frame(height: 10)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
            }
            .navigationBarBackButtonHidden(true)
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
