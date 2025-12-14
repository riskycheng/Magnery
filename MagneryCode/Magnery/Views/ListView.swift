import SwiftUI

struct ListView: View {
    @EnvironmentObject var store: MagnetStore
    let group: MagnetGroup
    @State private var sortByTime = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(sortedItems) { item in
                            NavigationLink(destination: DetailView(magnet: item)) {
                                MagnetCard(magnet: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    sortByTime.toggle()
                    store.groupingMode = sortByTime ? .time : .location
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: sortByTime ? "calendar" : "mappin.circle")
                        Text(sortByTime ? "按日期" : "按地点")
                            .font(.subheadline)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: sortByTime ? "calendar" : "mappin.circle.fill")
                    .foregroundColor(.primary)
                Text(group.title)
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            Text(group.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
    
    private var sortedItems: [MagnetItem] {
        group.items.sorted { $0.date > $1.date }
    }
}

struct MagnetCard: View {
    let magnet: MagnetItem
    
    var body: some View {
        VStack(spacing: 8) {
            if let image = ImageManager.shared.loadImage(filename: magnet.imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 150)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 150)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            
            Text(dateString)
                .font(.caption)
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white)
                .clipShape(Capsule())
        }
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: magnet.date)
    }
}

#Preview {
    NavigationStack {
        ListView(group: MagnetGroup(
            title: "未知位置",
            subtitle: "4个冰箱贴",
            items: [],
            color: .yellow.opacity(0.3)
        ))
        .environmentObject(MagnetStore())
    }
}
