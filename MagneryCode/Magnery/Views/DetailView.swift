import SwiftUI

struct DetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: MagnetStore
    let magnet: MagnetItem
    @State private var showingAIDialog = false
    @State private var showingEditMenu = false
    @State private var showingEditSheet = false
    @State private var currentMagnet: MagnetItem
    @State private var groupItems: [MagnetItem] = []
    
    init(magnet: MagnetItem) {
        self.magnet = magnet
        _currentMagnet = State(initialValue: magnet)
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.97)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if !groupItems.isEmpty {
                    horizontalItemsList
                        .padding(.top, 8)
                }
                
                Spacer()
                
                if let image = ImageManager.shared.loadImage(filename: currentMagnet.imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 350)
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 40)
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
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if showingEditMenu {
                circularMenuButtons
            }
        }
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
    }
    
    private var horizontalItemsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(groupTitle)
                .font(.headline)
                .padding(.horizontal)
            
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
                                    .scaleEffect(item.id == currentMagnet.id ? 1.1 : 1.0)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 80)
        }
    }
    
    private var circularMenuButtons: some View {
        ZStack {
            Button(action: {
                showingEditMenu = false
                showingEditSheet = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "pencil")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
            .offset(x: -65, y: 5)
            .scaleEffect(showingEditMenu ? 1 : 0.1)
            .opacity(showingEditMenu ? 1 : 0)
            
            Button(action: {
                showingEditMenu = false
                deleteMagnet()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "trash.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.red)
                }
            }
            .offset(x: 5, y: 65)
            .scaleEffect(showingEditMenu ? 1 : 0.1)
            .opacity(showingEditMenu ? 1 : 0)
        }
        .padding(.trailing, 16)
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
            group.items.contains(where: { $0.id == magnet.id })
        }) {
            groupItems = group.items.sorted { $0.date > $1.date }
        }
    }
    
    private func saveAsWallpaper() {
        guard let image = ImageManager.shared.loadImage(filename: currentMagnet.imagePath) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    
    private func deleteMagnet() {
        store.deleteMagnet(currentMagnet)
        dismiss()
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
