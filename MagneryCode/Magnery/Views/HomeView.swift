import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: MagnetStore
    @State private var showingCamera = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    headerView
                    
                    cameraButton
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(store.groupedMagnets()) { group in
                                NavigationLink(destination: ListView(group: group)) {
                                    GroupCard(group: group)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView()
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text(greeting)
                .font(.title)
                .fontWeight(.medium)
            
            Text("真棒！已经收集了\(store.magnets.count)个冰箱贴，走过\(uniqueLocationsCount)个城市")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }
    
    private var cameraButton: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(red: 1.0, green: 0.4, blue: 0.6),
                            Color(red: 0.4, green: 0.8, blue: 0.5),
                            Color(red: 1.0, green: 0.8, blue: 0.3),
                            Color(red: 0.5, green: 0.6, blue: 1.0),
                            Color(red: 0.8, green: 0.5, blue: 1.0),
                            Color(red: 1.0, green: 0.4, blue: 0.6)
                        ],
                        center: .center
                    ),
                    lineWidth: 8
                )
                .frame(width: 140, height: 140)
            
            Circle()
                .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
                .frame(width: 124, height: 124)
            
            Button(action: {
                showingCamera = true
            }) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 20)
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<6: return "凌晨好 :-)"
        case 6..<12: return "早上好 :-)"
        case 12..<18: return "下午好 :-)"
        default: return "晚上好 :-)"
        }
    }
    
    private var uniqueLocationsCount: Int {
        Set(store.magnets.map { $0.location }).count
    }
}

struct GroupCard: View {
    let group: MagnetGroup
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.primary)
                    Text(group.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Text(group.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                ForEach(group.items.prefix(2)) { item in
                    if let image = ImageManager.shared.loadImage(filename: item.imagePath) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding()
        .background(group.color)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    HomeView()
        .environmentObject(MagnetStore())
}
