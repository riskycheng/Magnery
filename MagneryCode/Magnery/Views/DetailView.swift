import SwiftUI

struct EllipsisButtonBoundsKey: PreferenceKey {
    static var defaultValue: CGRect?
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = value ?? nextValue()
    }
}

struct DetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: MagnetStore
    let magnet: MagnetItem
    @State private var showingAIDialog = false
    @State private var showingEditMenu = false
    @State private var showingEditSheet = false
    @State private var currentMagnet: MagnetItem
    @State private var groupItems: [MagnetItem] = []
    @State private var ellipsisButtonFrame: CGRect = .zero
    @State private var refreshTrigger: Bool = false
    @State private var showingDeleteConfirmation = false
    
    init(magnet: MagnetItem) {
        self.magnet = magnet
        _currentMagnet = State(initialValue: magnet)
    }
    
    var body: some View {
        ZStack {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if !groupItems.isEmpty {
                        horizontalItemsList
                            .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    if let gifPath = currentMagnet.gifPath {
                        NativeGIFView(url: ImageManager.shared.getFileURL(for: gifPath))
                            .frame(maxHeight: 350)
                            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                            .padding(.horizontal, 40)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                            .gesture(
                                DragGesture(minimumDistance: 30)
                                    .onEnded { value in
                                        handleSwipeGesture(translation: value.translation)
                                    }
                            )
                    } else if let image = ImageManager.shared.loadImage(filename: currentMagnet.imagePath) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 350)
                            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                            .padding(.horizontal, 40)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                            .gesture(
                                DragGesture(minimumDistance: 30)
                                    .onEnded { value in
                                        handleSwipeGesture(translation: value.translation)
                                    }
                            )
                    }
                    
                    VStack(spacing: 8) {
                        Text(currentMagnet.name)
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .foregroundColor(.primary)
                        
                        if !currentMagnet.notes.isEmpty {
                            Text(currentMagnet.notes)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    .padding(.top, 24)
                    
                    Spacer()
                    
                    Button(action: {
                        showingAIDialog = true
                    }) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                            Text("AI科普")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(Color.orange)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingEditMenu.toggle()
                    }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(
                                            key: EllipsisButtonBoundsKey.self,
                                            value: geo.frame(in: .global).midX > 0 ? geo.frame(in: .global) : nil
                                        )
                                }
                            )
                    }
                }
            }
            .onPreferenceChange(EllipsisButtonBoundsKey.self) { frame in
                if let frame = frame {
                    ellipsisButtonFrame = frame
                }
            }
            
            if showingEditMenu && ellipsisButtonFrame != .zero {
                circularMenuButtons
                    .position(
                        x: ellipsisButtonFrame.midX,
                        y: ellipsisButtonFrame.midY - 20
                    )
                    .zIndex(999)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            loadGroupItems()
        }
        .sheet(isPresented: $showingAIDialog) {
            AIDialogView(magnet: currentMagnet)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditMagnetSheet(magnet: $currentMagnet, onSave: {
                store.updateMagnet(currentMagnet)
                showingEditSheet = false
            })
        }
        .alert("确认删除", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteMagnet()
            }
        } message: {
            Text("确定要删除「\(currentMagnet.name)」吗？")
        }
    }
    
    private var horizontalItemsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(groupTitle)
                .font(.headline)
                .padding(.horizontal)
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(groupItems) { item in
                            Button(action: {
                                withAnimation {
                                    currentMagnet = item
                                }
                            }) {
                                if let image = ImageManager.shared.loadImage(filename: item.imagePath) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 60, height: 60)
                                        .opacity(item.id == currentMagnet.id ? 1.0 : 0.5)
                                        .scaleEffect(item.id == currentMagnet.id ? 1.3 : 0.9)
                                        .shadow(
                                            color: item.id == currentMagnet.id ? .blue.opacity(0.3) : .clear,
                                            radius: item.id == currentMagnet.id ? 8 : 0,
                                            x: 0,
                                            y: 2
                                        )
                                }
                            }
                            .id(item.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .frame(height: 100)
                .onChange(of: currentMagnet.id) { oldValue, newValue in
                    withAnimation {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .onAppear {
                    proxy.scrollTo(currentMagnet.id, anchor: .center)
                }
            }
        }
    }
    
    private var circularMenuButtons: some View {
        let buttonSize: CGFloat = 56
        // Calculate spacing relative to button size for consistency across devices
        // Edit button: positioned to the left with slight upward offset
        let editHorizontalOffset: CGFloat = buttonSize * 1.07  // ~60pt for 56pt button
        let editVerticalOffset: CGFloat = -buttonSize * 1.07   // ~-60pt for 56pt button
        // Delete button: positioned below with slight downward offset
        let deleteVerticalOffset: CGFloat = -buttonSize * 0.36 // ~-20pt for 56pt button
        
        return ZStack {
            // edit_circle_btn: positioned upper-left relative to menu_button
            Button(action: {
                showingEditMenu = false
                showingEditSheet = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: buttonSize, height: buttonSize)
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.blue)
                        .symbolRenderingMode(.hierarchical)
                }
                .contentShape(Circle())
            }
            .offset(x: -editHorizontalOffset, y: editVerticalOffset)
            .scaleEffect(showingEditMenu ? 1 : 0.1)
            .opacity(showingEditMenu ? 1 : 0)
            
            // delete_circle_btn: positioned below menu_button
            Button(action: {
                showingEditMenu = false
                showingDeleteConfirmation = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: buttonSize, height: buttonSize)
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.red)
                        .symbolRenderingMode(.hierarchical)
                }
                .contentShape(Circle())
            }
            .offset(x: 0, y: deleteVerticalOffset)
            .scaleEffect(showingEditMenu ? 1 : 0.1)
            .opacity(showingEditMenu ? 1 : 0)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showingEditMenu)
    }
    
    private var groupTitle: String {
        if store.groupingMode == .location {
            return currentMagnet.location
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日"
            return formatter.string(from: currentMagnet.date)
        }
    }
    
    private func loadGroupItems() {
        let groups = store.groupedMagnets()
        if let group = groups.first(where: { group in
            group.items.contains(where: { $0.id == currentMagnet.id })
        }) {
            groupItems = group.items.sorted { $0.date > $1.date }
        } else {
            groupItems = []
        }
    }
    
    private func saveAsWallpaper() {
        guard let image = ImageManager.shared.loadImage(filename: currentMagnet.imagePath) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    
    private func handleSwipeGesture(translation: CGSize) {
        guard !groupItems.isEmpty else { return }
        
        let currentIndex = groupItems.firstIndex(where: { $0.id == currentMagnet.id }) ?? 0
        
        // 右滑 (translation.width > 0) -> 上一个item
        // 左滑 (translation.width < 0) -> 下一个item
        if translation.width > 0 {
            // 右滑：切换到上一个
            if currentIndex > 0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentMagnet = groupItems[currentIndex - 1]
                    refreshTrigger.toggle()
                }
            }
        } else if translation.width < 0 {
            // 左滑：切换到下一个
            if currentIndex < groupItems.count - 1 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentMagnet = groupItems[currentIndex + 1]
                    refreshTrigger.toggle()
                }
            }
        }
    }
    
    private func deleteMagnet() {
        let currentIndex = groupItems.firstIndex(where: { $0.id == currentMagnet.id })
        
        // 在删除前，从当前的groupItems中确定下一个要显示的item
        var nextMagnet: MagnetItem?
        if let index = currentIndex {
            // 创建删除后的临时列表
            var tempItems = groupItems
            tempItems.remove(at: index)
            
            if !tempItems.isEmpty {
                // 优先显示同索引位置的item，如果超出范围则显示前一个
                if index < tempItems.count {
                    nextMagnet = tempItems[index]
                } else if index > 0 {
                    nextMagnet = tempItems[index - 1]
                } else {
                    nextMagnet = tempItems[0]
                }
            }
        }
        
        // 执行删除
        store.deleteMagnet(currentMagnet)
        
        DispatchQueue.main.async {
            if let next = nextMagnet {
                // 有下一个item，切换过去
                currentMagnet = next
                loadGroupItems()
                refreshTrigger.toggle()
            } else {
                // 没有下一个item，返回上一级
                dismiss()
            }
        }
    }
}

struct AIDialogView: View {
    @Environment(\.dismiss) var dismiss
    let magnet: MagnetItem
    @State private var aiResponse: String = ""
    @State private var isListening = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            VStack {
                Spacer()
                
                VStack(spacing: 20) {
                    HStack {
                        Spacer()
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(generateAIResponse())
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding()
                        }
                    }
                    .frame(maxHeight: 300)
                    
                    VStack(spacing: 12) {
                        Button(action: {
                            isListening.toggle()
                        }) {
                            HStack {
                                Image(systemName: "mic.fill")
                                Text("语音提问")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.6))
                            .clipShape(Capsule())
                        }
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Text("知道了")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding()
            }
        }
    }
    
    private func generateAIResponse() -> String {
        let responses = [
            "\(magnet.name)是一个有趣的收藏品。它代表着特定的文化符号和记忆。\n\n收藏这类物品是一种有意义的爱好，可以通过触觉和视觉来增强记忆效果。",
            "\(magnet.name)具有独特的设计特点。这类物品通常用于装饰和纪念。\n\n使用冰箱贴收藏是一种有趣的学习方法，可以通过触觉和视觉范围同时记忆，增强儿童的学习效果。",
            "关于\(magnet.name)：这是一个很有意思的收藏品。\n\n它代表着你在\(magnet.location)的美好回忆。每个冰箱贴都承载着独特的故事和经历。"
        ]
        return responses.randomElement() ?? responses[0]
    }
}

#Preview {
    NavigationStack {
        DetailView(magnet: MagnetItem(
            name: "字母B",
            date: Date(),
            location: "上海市黄浦区",
            imagePath: "",
            notes: "终于找到了B，太幸运了！"
        ))
    }
}
