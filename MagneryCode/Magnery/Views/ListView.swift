import SwiftUI

struct ListView: View {
    @EnvironmentObject var store: MagnetStore
    @Environment(\.horizontalSizeClass) var sizeClass
    let group: MagnetGroup?
    let scrollToGroup: Bool
    let scrollToItemId: UUID?
    let isFavoritesOnly: Bool
    @State private var selectedItemId: UUID? = nil
    @State private var groups: [MagnetGroup] = []
    @State private var itemToShare: MagnetItem? = nil
    @Namespace private var scrollNamespace
    
    private var isIPad: Bool {
        sizeClass == .regular
    }
    
    private var columns: [GridItem] {
        if isIPad {
            return [
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20)
            ]
        } else {
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        }
    }
    
    init(group: MagnetGroup? = nil, scrollToGroup: Bool = false, scrollToItemId: UUID? = nil, isFavoritesOnly: Bool = false) {
        self.group = group
        self.scrollToGroup = scrollToGroup
        self.scrollToItemId = scrollToItemId
        self.isFavoritesOnly = isFavoritesOnly
    }
    
    var body: some View {
        ZStack {
            DottedBackgroundView()
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    deselectItem()
                }
            
            if groups.isEmpty && isFavoritesOnly {
                emptyFavoritesView
            } else {
                contentScrollView
            }
        }
        .setTabBarVisibility(false)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(isFavoritesOnly ? "我的收藏" : "")
        .toolbar {
            if !isFavoritesOnly {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ListView(isFavoritesOnly: true)) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .onAppear {
            updateGroups()
        }
        .onChange(of: store.magnets) { _ in
            updateGroups()
        }
        .sheet(item: $itemToShare) { item in
            SharePreviewView(item: item)
        }
    }
    
    private var emptyFavoritesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            Text("暂无收藏")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("长按冰箱贴并点击爱心即可收藏")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
        }
    }
    
    private func updateGroups() {
        if isFavoritesOnly {
            groups = store.groupedMagnets(filter: { $0.favoriteStatus })
        } else {
            groups = store.groupedMagnets()
        }
    }
    
    private var contentScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 30) {
                    ForEach(groups) { currentGroup in
                        VStack(spacing: 20) {
                            headerView(for: currentGroup)
                            magnetGrid(for: currentGroup)
                        }
                        .id(currentGroup.id)
                    }
                }
                .padding(.top)
                .contentShape(Rectangle())
                .onTapGesture {
                    deselectItem()
                }
            }
            .onAppear {
                if scrollToGroup, let targetGroup = group {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let itemId = scrollToItemId {
                            withAnimation {
                                proxy.scrollTo(itemId, anchor: .center)
                            }
                        } else {
                            withAnimation {
                                proxy.scrollTo(targetGroup.id, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func magnetGrid(for group: MagnetGroup) -> some View {
        LazyVGrid(columns: columns, spacing: isIPad ? 20 : 16) {
            ForEach(group.items.sorted { $0.date > $1.date }) { item in
                magnetItemView(for: item)
                    .id(item.id)
            }
        }
        .padding(.horizontal)
    }
    
    private func magnetItemView(for item: MagnetItem) -> some View {
        ZStack(alignment: .topTrailing) {
            magnetCardLink(for: item)
            
            if selectedItemId == item.id {
                actionButtons(for: item)
            }
        }
    }
    
    private func magnetCardLink(for item: MagnetItem) -> some View {
        NavigationLink(destination: DetailView(magnet: item)) {
            MagnetCard(
                magnet: item,
                isSelected: selectedItemId == item.id,
                isDimmed: selectedItemId != nil && selectedItemId != item.id
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(selectedItemId != nil)
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            handleLongPress(for: item)
        })
    }
    
    private func actionButtons(for item: MagnetItem) -> some View {
        VStack(spacing: 12) {
            favoriteButton(for: item)
            shareButton(for: item)
            deleteButton(for: item)
        }
        .offset(x: -8, y: -8)
        .transition(.scale.combined(with: .opacity))
    }
    
    private func favoriteButton(for item: MagnetItem) -> some View {
        Button(action: {
            handleToggleFavorite(for: item)
        }) {
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .overlay(
                    Image(systemName: item.favoriteStatus ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundColor(item.favoriteStatus ? .red : .gray)
                )
        }
    }
    
    private func handleToggleFavorite(for item: MagnetItem) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        store.toggleFavorite(item)
    }
    
    private func shareButton(for item: MagnetItem) -> some View {
        Button(action: {
            itemToShare = item
        }) {
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .overlay(
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                )
        }
    }
    
    private func deleteButton(for item: MagnetItem) -> some View {
        Button(action: {
            handleDelete(for: item)
        }) {
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .overlay(
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                )
        }
    }
    
    private func handleLongPress(for item: MagnetItem) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedItemId = item.id
        }
    }
    
    private func handleDelete(for item: MagnetItem) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            store.deleteMagnet(item)
            selectedItemId = nil
        }
    }
    
    private func deselectItem() {
        if selectedItemId != nil {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedItemId = nil
            }
        }
    }
    
    private func headerView(for group: MagnetGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: store.groupingMode == .location ? "mappin.circle.fill" : "calendar")
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
    
}

struct MagnetCard: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    let magnet: MagnetItem
    var isSelected: Bool = false
    var isDimmed: Bool = false
    @State private var outlineImage: UIImage? = nil
    
    private var cardWidth: CGFloat {
        let columns: CGFloat = sizeClass == .regular ? 3 : 2
        let spacing: CGFloat = sizeClass == .regular ? 20 : 16
        let padding: CGFloat = 16 * 2
        return (UIScreen.main.bounds.width - padding - (spacing * (columns - 1))) / columns
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background card
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                
                if let gifPath = magnet.gifPath {
                    NativeGIFView(url: ImageManager.shared.getFileURL(for: gifPath))
                        .aspectRatio(contentMode: .fit)
                        .padding(15)
                        .frame(width: cardWidth, height: cardWidth)
                } else if let image = ImageManager.shared.loadImage(filename: magnet.imagePath) {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(15)
                            .frame(width: cardWidth, height: cardWidth)
                        
                        if let outline = outlineImage {
                            Image(uiImage: outline)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(15)
                                .frame(width: cardWidth, height: cardWidth)
                        }
                    }
                    .onAppear {
                        if outlineImage == nil {
                            DispatchQueue.global(qos: .userInitiated).async {
                                let outline = ImageOutlineHelper.createOutline(from: image, lineWidth: 3, offset: 2)
                                DispatchQueue.main.async {
                                    self.outlineImage = outline
                                }
                            }
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: cardWidth, height: cardWidth)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray.opacity(0.3))
                        )
                }
                
                // 3D Indicator
                if magnet.modelPath != nil {
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 28, height: 28)
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                
                                Image(systemName: "arkit")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: cardWidth, height: cardWidth)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            
            Text(magnet.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.05))
                .clipShape(Capsule())
        }
        .scaleEffect(isSelected ? 0.95 : 1.0)
        .opacity(isDimmed ? 0.6 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    NavigationStack {
        ListView()
            .environmentObject(MagnetStore())
    }
}
