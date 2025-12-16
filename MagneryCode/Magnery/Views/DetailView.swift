import SwiftUI

struct DetailView: View {
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
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                VStack(spacing: 20) {
                    if let image = ImageManager.shared.loadImage(filename: magnet.imagePath) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(radius: 10)
                            .padding(.horizontal, 40)
                    }
                    
                    VStack(spacing: 12) {
                        Text(magnet.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(dateString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if !magnet.notes.isEmpty {
                            Text("\"\(magnet.notes)\"")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showingAIDialog = true
                }) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                        Text("AI 科普")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .clipShape(Capsule())
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAIDialog) {
            AIDialogView(magnet: magnet)
        }
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: magnet.date)
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
