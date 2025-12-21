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
                    
                    // Input Triggers
                    VStack(spacing: 12) {
                        // Name Trigger
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showingInputDialog = true
                            }
                            // Small delay to ensure the view is rendered before focusing
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
                        
                        // Notes Trigger
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showingInputDialog = true
                            }
                            // Small delay to ensure the view is rendered before focusing
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                focusedField = .notes
                            }
                        }) {
                            HStack(alignment: .top) {
                                Text(notes.isEmpty ? "添加描述 (可选)..." : notes)
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(notes.isEmpty ? .gray.opacity(0.4) : .secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(minHeight: 40, alignment: .topLeading)
                                Spacer()
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray.opacity(0.4))
                                    .padding(.top, 2)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .frame(width: 280, height: 72)
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.bottom, 20)
                    
                    Spacer()
                    
                    // Bottom Action Buttons (Main Page)
                    if !showingInputDialog {
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
                                    Circle()
                                        .fill(name.isEmpty ? Color.gray.opacity(0.25) : Color(red: 0.3, green: 0.8, blue: 0.5))
                                        .frame(width: 82, height: 82)
                                    
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
                                        Image(systemName: "xmark")
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundColor(Color.gray.opacity(0.7))
                                    )
                                    .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                            }
                        }
                        .padding(.bottom, 44)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
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
                    
                    VStack(spacing: 0) {
                        VStack(spacing: 24) {
                            Text(focusedField == .name ? "输入对象名称" : "添加描述")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                            
                            ZStack(alignment: .trailing) {
                                if focusedField == .name {
                                    TextField("玩偶", text: $name)
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .multilineTextAlignment(.center)
                                        .focused($focusedField, equals: .name)
                                        .submitLabel(.done)
                                        .lineLimit(1)
                                        .textInputAutocapitalization(.words)
                                        .autocorrectionDisabled(true)
                                        .onSubmit {
                                            withAnimation {
                                                showingInputDialog = false
                                                focusedField = nil
                                            }
                                        }
                                } else {
                                    HStack(alignment: .center, spacing: 12) {
                                        TextField("添加描述 (可选)", text: $notes, axis: .vertical)
                                            .font(.system(size: 20, weight: .medium, design: .rounded))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .frame(minHeight: 50)
                                            .focused($focusedField, equals: .notes)
                                            .textInputAutocapitalization(.sentences)
                                            .autocorrectionDisabled(true)
                                        
                                        if !name.isEmpty {
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
                                                            .font(.system(size: 16, weight: .semibold))
                                                            .foregroundColor(.orange)
                                                    }
                                                }
                                                .frame(width: 36, height: 36)
                                                .background(Circle().fill(Color.orange.opacity(0.1)))
                                            }
                                        }
                                    }
                                }
                            }
                            
                            VStack(spacing: 16) {
                                Button(action: {
                                    withAnimation {
                                        showingInputDialog = false
                                        focusedField = nil
                                    }
                                }) {
                                    Text("确定")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.black.opacity(0.8), Color.black.opacity(0.7)]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .cornerRadius(28)
                                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                }
                                
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
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 12) // Margin from keyboard
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.9))
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
