import SwiftUI

struct SettingsDetailView: View {
    @EnvironmentObject var store: MagnetStore
    let title: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if title == "隐私政策" {
                    privacyPolicyContent
                } else if title == "服务条款" {
                    termsOfServiceContent
                } else if title == "常见问题" {
                    faqContent
                } else if title == "关于 Magnery" {
                    aboutMagneryContent
                } else {
                    placeholderSection
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var privacyPolicyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("隐私政策")
                .font(.title2)
                .bold()
            
            Text("Magnery 非常重视您的隐私。我们致力于保护您的个人信息并透明地说明我们的数据处理方式。")
            
            GroupBox(label: Label("数据收集", systemImage: "info.circle")) {
                Text("我们不会收集、存储或分享您的任何个人数据、照片或位置信息。所有的图片处理和识别均在您的设备本地完成。")
                    .padding(.top, 4)
            }
            
            GroupBox(label: Label("第三方服务", systemImage: "network")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("为了提供先进的 AI 功能，我们采用了以下服务：")
                    BulletPoint(text: "SiliconFlow AI API：用于生成科普内容和对话。")
                    BulletPoint(text: "SiliconFlow TTS：用于语音播报服务。")
                    Text("在调用这些接口时，我们仅传输必要的内容（如文本或经过处理的图片特征），且不会关联您的个人身份信息。")
                }
                .padding(.top, 4)
            }
            
            Text("如果您对我们的隐私政策有任何疑问，请通过意见反馈与我们联系。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var termsOfServiceContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("服务条款")
                .font(.title2)
                .bold()
            
            SectionView(title: "1. 服务说明", content: "Magnery 提供基于 AI 的冰箱贴识别、收藏管理、3D 模型生成及科普对话服务。")
            
            SectionView(title: "2. 免责声明", content: "AI 生成的内容（包括科普知识和对话回复）仅供参考，不代表绝对的准确性。用户应对其使用行为负责。")
            
            SectionView(title: "3. 隐私保护", content: "我们严格遵守隐私政策，保护用户数据安全。详情请参阅隐私政策页面。")
            
            SectionView(title: "4. 知识产权", content: "Magnery 应用及其包含的所有原创内容、设计和算法均受版权法保护。用户生成的创意内容归用户所有。")
        }
    }
    
    private var faqContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("常见问题")
                .font(.title2)
                .bold()
            
            FAQItem(question: "物体识别算法是如何工作的？", answer: "我们采用了 iOS 原生的 Vision SDK 进行高效的本地图像分析和特征提取。")
            
            FAQItem(question: "自动标注的大语言模型来自哪里？", answer: "自动标注和科普内容由硅基流动（SiliconFlow）API 提供的千问（Qwen）系列大模型服务支持。")
            
            FAQItem(question: "3D 模型是如何生成的？", answer: "我们采用腾讯混元 3D（Hunyuan3D）的服务，将您拍摄并分割好的 2D 图片转化为对应的 3D 模型。")
            
            FAQItem(question: "我的隐私和数据安全吗？", answer: "非常安全。核心识别算法在本地运行。远程 AI 调用均经过加密传输，且我们不会在服务器端缓存或收集任何用户数据。")
        }
    }
    
    private var aboutMagneryContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("关于 Magnery")
                .font(.title2)
                .bold()
            
            Text("什么是 Magnery？")
                .font(.headline)
            Text("Magnery 是一款专为收藏爱好者设计的创意工具。用户可以通过拍摄、加载图片或视频等方式，设计自己喜爱的虚拟冰箱贴，也可以用于记录精致的手办收藏。")
            
            Text("核心功能")
                .font(.headline)
                .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 10) {
                FeatureRow(icon: "photo.on.rectangle", text: "支持图片、视频及 GIF 动效展示")
                FeatureRow(icon: "cube.fill", text: "2D 图片一键生成 3D 模型")
                FeatureRow(icon: "tag.fill", text: "AI 自动标注与分类管理")
                FeatureRow(icon: "book.fill", text: "AI 深度知识科普与互动对话")
            }
        }
    }
    
    private var placeholderSection: some View {
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
    }
}

struct BulletPoint: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .bold()
            Text(text)
        }
    }
}

struct SectionView: View {
    let title: String
    let content: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 8)
    }
}

struct FAQItem: View {
    let question: String
    let answer: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.headline)
                .foregroundColor(.primary)
            Text(answer)
                .foregroundColor(.secondary)
            Divider()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsDetailView(title: "关于 Magnery")
    }
}
