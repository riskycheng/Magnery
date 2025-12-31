import SwiftUI

struct SettingsDetailView: View {
    @EnvironmentObject var store: MagnetStore
    let title: String
    
    var body: some View {
        List {
            if title == "系统语言" {
                languageSection
            } else if title == "大模型选择" {
                llmSection
            } else {
                placeholderSection
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var languageSection: some View {
        Section {
            ForEach(["简体中文", "English", "日本語", "Français"], id: \.self) { lang in
                Button(action: {
                    store.systemLanguage = lang
                    store.saveSettings()
                }) {
                    HStack {
                        Text(lang)
                            .foregroundColor(.primary)
                        Spacer()
                        if store.systemLanguage == lang {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        } footer: {
            Text("更改语言后可能需要重启应用以完全生效。")
        }
    }
    
    private var llmSection: some View {
        Group {
            Section(header: Text("描述生成 (Caption Generation)")) {
                ForEach(["通用", "进阶"], id: \.self) { model in
                    Button(action: {
                        store.captionModel = model
                        store.saveSettings()
                    }) {
                        HStack {
                            Text(model)
                                .foregroundColor(.primary)
                            Spacer()
                            if store.captionModel == model {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                }
            }
            
            Section(header: Text("对话 (Dialogue)")) {
                ForEach(["通用", "标准", "多模态"], id: \.self) { model in
                    Button(action: {
                        store.dialogueModel = model
                        store.saveSettings()
                    }) {
                        HStack {
                            Text(model)
                                .foregroundColor(.primary)
                            Spacer()
                            if store.dialogueModel == model {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var placeholderSection: some View {
        Section {
            VStack(spacing: 20) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .padding(.top, 40)
                
                Text("\(title) 正在开发中")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text("我们正在努力完善此功能，敬请期待。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsDetailView(title: "通知设置")
    }
}
