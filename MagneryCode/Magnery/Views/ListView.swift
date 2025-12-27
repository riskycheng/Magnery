import SwiftUI

struct ListView: View {
    @EnvironmentObject var store: MagnetStore
    let group: MagnetGroup?
    let scrollToGroup: Bool
    @State private var selectedItemId: UUID? = nil
    @State private var groups: [MagnetGroup] = []
    @State private var itemToShare: MagnetItem? = nil
    @Namespace private var scrollNamespace
    
    init(group: MagnetGroup? = nil, scrollToGroup: Bool = false) {
        self.group = group
        self.scrollToGroup = scrollToGroup
    }
    
    var body: some View {
        ZStack {
            DottedBackgroundView()
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    deselectItem()
                }
            
            contentScrollView
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            groups = store.groupedMagnets()
        }
        .onChange(of: store.magnets) { _ in
            groups = store.groupedMagnets()
        }
        .sheet(item: $itemToShare) { item in
            if let image = ImageManager.shared.loadImage(filename: item.imagePath) {
                ShareSheet(activityItems: [image])
                    .presentationDetents([.medium, .large])
            }
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
                        withAnimation {
                            proxy.scrollTo(targetGroup.id, anchor: .top)
                        }
                    }
                }
            }
        }
    }
    
    private func magnetGrid(for group: MagnetGroup) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            ForEach(group.items.sorted { $0.date > $1.date }) { item in
                magnetItemView(for: item)
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
            shareButton(for: item)
            deleteButton(for: item)
        }
        .offset(x: -8, y: -8)
        .transition(.scale.combined(with: .opacity))
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
                        .foregroundColor(.gray)
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
    let magnet: MagnetItem
    var isSelected: Bool = false
    var isDimmed: Bool = false
    @State private var outlineImage: UIImage? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if let gifPath = magnet.gifPath {
                    GIFView(url: ImageManager.shared.getFileURL(for: gifPath))
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                } else if let image = ImageManager.shared.loadImage(filename: magnet.imagePath) {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 150)
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        
                        if let outline = outlineImage {
                            Image(uiImage: outline)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 150)
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 150)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }
            }
            
            Text(magnet.name)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .lineLimit(1)
        }
        .opacity(isDimmed ? 0.3 : 1.0)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isDimmed)
    }
}

struct DottedBackgroundView: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let dotSize: CGFloat = 2
                let spacing: CGFloat = 20
                let dotColor = Color.gray.opacity(0.15)
                
                let columns = Int(size.width / spacing) + 1
                let rows = Int(size.height / spacing) + 1
                
                for row in 0..<rows {
                    for col in 0..<columns {
                        let x = CGFloat(col) * spacing
                        let y = CGFloat(row) * spacing
                        
                        let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                        context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    }
                }
            }
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
    }
}

#Preview {
    NavigationStack {
        ListView()
            .environmentObject(MagnetStore())
    }
}
