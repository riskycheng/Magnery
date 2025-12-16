import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: MagnetStore
    @State private var showingCamera = false
    @State private var ringRotation: Double = 0
    @State private var cameraScale: CGFloat = 1.0
    @State private var showGroupingToggle = false
    @State private var dotScales: [CGFloat] = Array(repeating: 1.0, count: 8)
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    headerView
                    
                    cameraButton
                    
                    groupingToggle
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(store.groupedMagnets()) { group in
                                NavigationLink(destination: ListView(group: group)) {
                                    GroupCard(group: group, groupingMode: store.groupingMode)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                    .animation(nil, value: ringRotation)
                    .animation(nil, value: cameraScale)
                    .animation(nil, value: dotScales)
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
            ColorfulRing()
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(ringRotation))
                .onAppear {
                    withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                        ringRotation = 360
                    }
                }
            
            ForEach(0..<8) { index in
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(dotScales[index])
                    .offset(y: -110)
                    .rotationEffect(.degrees(Double(index) * 45))
                    .onAppear {
                        withAnimation(
                            Animation.easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1)
                        ) {
                            dotScales[index] = 1.8
                        }
                    }
            }
            
            Circle()
                .fill(Color.white)
                .frame(width: 80, height: 80)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            Button(action: {
                showingCamera = true
            }) {
                Image(systemName: "camera")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.black)
            }
            .scaleEffect(cameraScale)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    cameraScale = 1.15
                }
            }
        }
        .padding(.vertical, 20)
        .transaction { transaction in
            transaction.animation = nil
        }
    }
    
    
    private var groupingToggle: some View {
        HStack {
            Spacer()
            Button(action: {
                store.groupingMode = store.groupingMode == .location ? .time : .location
            }) {
                HStack(spacing: 6) {
                    Image(systemName: store.groupingMode == .location ? "mappin" : "calendar")
                        .font(.system(size: 14))
                    Text(store.groupingMode == .location ? "按地点" : "按日期")
                        .font(.subheadline)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal)
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

struct ColorfulRing: View {
    let colors: [Color] = [
        Color(red: 1.0, green: 0.4, blue: 0.6),
        Color(red: 0.4, green: 0.8, blue: 0.5),
        Color(red: 1.0, green: 0.8, blue: 0.3),
        Color(red: 0.5, green: 0.6, blue: 1.0),
        Color(red: 0.8, green: 0.5, blue: 1.0)
    ]
    
    var body: some View {
        ZStack {
            ForEach(0..<colors.count, id: \.self) { index in
                Circle()
                    .trim(from: CGFloat(index) / CGFloat(colors.count),
                          to: CGFloat(index + 1) / CGFloat(colors.count) + 0.01)
                    .stroke(colors[index], style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

struct GroupCard: View {
    let group: MagnetGroup
    let groupingMode: GroupingMode
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: groupingMode == .location ? "mappin.circle.fill" : "calendar")
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
