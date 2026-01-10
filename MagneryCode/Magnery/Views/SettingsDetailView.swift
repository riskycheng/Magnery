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
        .setTabBarVisibility(false)
    }
    
    private var privacyPolicyContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("隐私政策")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text("更新日期：2026年1月10日")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Magnery (“我们”) 非常重视您的个人隐私保护。本政策旨在说明我们如何处理您的数据，确保您在使用我们的服务时感到安心。")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                PolicySection(title: "1. 核心原则", icon: "shield.fill", color: .green) {
                    Text("我们坚持“隐私先行”的设计理念。除非服务必需，我们不会请求、收集或存储任何超出功能范围外的个人信息。")
                }
                
                PolicySection(title: "2. 数据收集与处理", icon: "lock.doc.fill", color: .blue) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("• 图像与多媒体数据")
                            .fontWeight(.semibold)
                        Text("您拍摄或上传的所有冰箱贴照片、GIF 及视频均**仅存储在您的设备本地**。核心的识别与分割算法（Vision SDK）均在本地运行，不会上传至我们的服务器。")
                        
                        Text("• 位置信息")
                            .fontWeight(.semibold)
                        Text("本应用申请的位置权限仅用于记录冰箱贴的地理标签（如：在上海购买）。此数据存储在设备本地数据库中，不会对外分享。")
                    }
                }
                
                PolicySection(title: "3. 第三方 AI 协作说明", icon: "sparkles", color: .purple) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("为了实现先进的 AI 标注及 3D 模型生成，我们会与以下服务商协作：")
                        
                        // Provider Table Header
                        HStack {
                            Text("服务商").frame(width: 100, alignment: .leading)
                            Text("处理内容").frame(maxWidth: .infinity, alignment: .leading)
                            Text("链接").frame(width: 60, alignment: .trailing)
                        }
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                        
                        Divider()
                        
                        // Row 1: SiliconFlow
                        ProviderRow(name: "SiliconFlow", content: "AI 科普文字生成及语音合成", url: "https://siliconflow.cn")
                        Divider()
                        
                        // Row 2: Tencent Hunyuan
                        ProviderRow(name: "腾讯混元", content: "2D 图像生成 3D 模型引擎", url: "https://hunyuan.tencent.com")
                        Divider()
                        
                        // Row 3: Tencent COS
                        ProviderRow(name: "腾讯云 COS", content: "社区数据存储与分发", url: "https://cloud.tencent.com")
                        
                        Text("所有远程调用均通过加密通道传输，且服务商不得将此类数据用于训练或非服务用途。")
                            .font(.system(size: 12))
                            .italic()
                    }
                }
                
                PolicySection(title: "4. 数据存储与安全", icon: "server.rack", color: .orange) {
                    Text("您的收藏数据和个人配置均保存在系统的私有目录中。我们采用系统级的沙盒保护机制，防止第三方应用非法获取数据。")
                }
                
                PolicySection(title: "5. 您的权利", icon: "hand.tap.fill", color: .indigo) {
                    Text("您可以随时在设置中清理应用缓存或清空收藏库。一旦删除，相关本地数据将无法恢复。")
                }
                
                PolicySection(title: "6. 联系与支持", icon: "envelope.badge.fill", color: .pink) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("如果您对隐私政策、数据处理或应用使用有任何疑问，请随时联系我们：")
                        Link("riskycheng@gmail.com", destination: URL(string: "mailto:riskycheng@gmail.com")!)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            VStack(alignment: .center, spacing: 12) {
                Text("如果您对本政策有任何疑问，请通过“意见反馈”与我们交流。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Magnery 团队敬上")
                    .font(.headline)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        }
    }
    
    private var termsOfServiceContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("服务条款")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("生效日期：2026年1月10日")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("欢迎使用 Magnery。使用本应用即表示您同意以下协议条款。请务必仔细阅读。")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 24) {
                TOSSection(title: "1. 服务协议的确认", content: "本协议是您与 Magnery 团队之间关于下载、安装、使用本移动应用所订立的协议。")
                
                TOSSection(title: "2. 账号与安全", content: "您无需注册账号即可使用核心功能。您的昵称、头像及收藏数据均保存在本地或您的 iCloud 私有空间中。")
                
                TOSSection(title: "3. 用户行为规范", content: "您承诺在使用本应用生成的 3D 模型或 AI 内容时，遵守当地法律法规，不传播违法或侵权信息。")
                
                TOSSection(title: "4. AI 服务免责", content: "应用提供的 AI 识别、3D 模型转换及科普知识由第三方技术支持，结果受模型限制可能存在误差。相关内容仅供参考，不构成专业建议。")
                
                TOSSection(title: "5. 知识产权", content: "Magnery 及其所有原始素材版权归开发团队所有。用户通过 App 拍摄并处理生成的模型，在遵守法律的前提下，其数字资产所有权归用户。")
                
                TOSSection(title: "6. 协议更新", content: "我们可能会适时更新本条款。更新后如果您继续使用，即视为接受新条款。")
            }
            .padding(.top, 10)
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
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .frame(width: 100, height: 100)
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
                
                VStack(spacing: 4) {
                    Text("Magnery")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Version 1.0.0 (2026)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            
            VStack(alignment: .leading, spacing: 20) {
                AboutSection(title: "什么是 Magnery？") {
                    Text("Magnery 是一款专为冰箱贴及小比例模型收藏家打造的数字化管理平台。我们利用尖端的 Vision AI 与 3D 重建技术，将您的实物收藏转化为生动的数字资产。")
                }
                
                AboutSection(title: "核心亮点") {
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "camera.viewfinder", text: "全自动 AI 分割与物体识别", color: .blue)
                        FeatureRow(icon: "cube.transparent.fill", text: "2D 到 3D 快速建模重建", color: .purple)
                        FeatureRow(icon: "sparkles.rectangle.stack", text: "多维度分类与地理标签管理", color: .orange)
                        FeatureRow(icon: "brain.headset", text: "智能科普对话与知识拓展", color: .green)
                    }
                }
                
                AboutSection(title: "我们的愿景") {
                    Text("连接现实与数字世界，让每一份珍贵的收藏都能在数字空间中永久珍藏、自由展示与分享。")
                }
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
                .foregroundColor(.orange)
            Text(text)
        }
    }
}

struct TOSSection: View {
    let title: String
    let content: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(content)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineSpacing(4)
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

struct PolicySection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            content
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .padding(.leading, 24)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 4)
    }
}

struct AboutSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            content
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14, weight: .bold))
            }
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
    }
}
struct ProviderRow: View {
    let name: String
    let content: String
    let url: String
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .frame(width: 100, alignment: .leading)
                .font(.system(size: 14, weight: .bold))
            
            Text(content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Link(destination: URL(string: url)!) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .foregroundColor(.blue.opacity(0.8))
            }
            .frame(width: 60, alignment: .trailing)
        }
    }
}
#Preview {
    NavigationStack {
        SettingsDetailView(title: "关于 Magnery")
    }
}
