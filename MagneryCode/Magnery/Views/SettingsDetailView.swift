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
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("服务条款")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("生效日期：2026年1月10日")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("欢迎使用 Magnery。本协议是您与 Magnery 团队（“我们”）之间就使用本应用服务所订立的法律协议。使用本应用即表示您已阅读并同意本条款。")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                TOSBlock(title: "1. 服务的性质", icon: "sparkles.rectangle.stack") {
                    Text("Magnery 提供基于 AI 的冰箱贴管理、识别及 3D 重建服务。我们致力于不断改进技术，但可能随时根据产品策略调整功能模块。")
                }
                
                TOSBlock(title: "2. 用户账号与数据", icon: "person.text.rectangle") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("• 您无需注册即可使用。您的数据托管于本地及您的 iCloud 私人存储。")
                        Text("• 您应妥善保管设备及个人备份信息，我们不对因用户个人失误导致的数据丢失负责。")
                    }
                }
                
                TOSBlock(title: "3. 知识产权声明", icon: "c.circle") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("• **我们的权利**：Magnery 品牌、源代码、UI 设计及内置 AI 算法模型均受知识产权法保护。")
                        Text("• **您的权利**：您拍摄的照片及通过 App 生成的独创性数字资源（如 3D 模型）的所有权归您所有。")
                    }
                }
                
                TOSBlock(title: "4. 使用规范与合规", icon: "hand.raised.fill") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("您理解并同意，在使用本服务时将遵守法律法规，不得利用本应用制作或存储任何具有误导性、侵权性或危害性的数字内容。")
                    }
                }
                
                TOSBlock(title: "5. 免责声明", icon: "exclamationmark.shield") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("• **AI 的局限性**：AI 生成的科普信息与 3D 转换结果仅供参考，我们不保证其 100% 的准确性。")
                        Text("• **第三方服务**：服务中集成了 SiliconFlow 与腾讯云等服务提供商，其稳定性受相应服务商 SLA 影响。")
                    }
                }
                
                TOSBlock(title: "6. 协议的变更", icon: "arrow.up.doc") {
                    Text("我们保留在必要时修改本协议的权利。修改后的协议将通过应用更新或公告形式告知。继续使用即视为接受。")
                }
            }
        }
    }
    
    private var faqContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("常见问题")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("帮助您更好地了解与使用 Magnery")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                FAQBlock(
                    question: "物体识别与抠图是如何实现的？",
                    answer: "我们采用了 iOS 原生的 Vision SDK 与 Core ML 技术。所有的抠图与边缘识别均在您的 iPhone 本地实时完成，不依赖网络，且能最大程度保护您的照片隐私。"
                )
                
                FAQBlock(
                    question: "AI 生成的科普内容是否准确？",
                    answer: "科普内容由硅基流动提供的 Qwen 系列大模型生成。虽然 AI 具有极高的准确率，但仍可能存在“幻觉”现象。相关地理与文化知识仅供参考，建议在专业场合进行二次核实。"
                )
                
                FAQBlock(
                    question: "3D 模型生成的流程是怎样的？",
                    answer: "当您为冰箱贴发起 3D 转换时，我们会将处理后的透明图片特征发送至腾讯混元 3D 引擎。生成的 USDZ 模型会自动同步回您的本地库中，您可以随时使用 AR 模式查看。"
                )
                
                FAQBlock(
                    question: "为什么有些物体识别不出来？",
                    answer: "识别效果受光照、拍摄角度以及物体复杂度的影响。建议在光线充足的环境下，从正面垂直角度拍摄识别目标，以获得最佳的分割效果。"
                )
                
                FAQBlock(
                    question: "我的数据会同步到云端吗？",
                    answer: "Magnery 默认将数据存储在您的设备本地。如果您开启了系统的 iCloud 云存储功能，您的收藏数据会自动在您的 Apple 设备间同步。我们不建立独立的账号体系，以保证数据的绝对隐私。"
                )
                
                FAQBlock(
                    question: "我想反馈问题或建议，该怎么做？",
                    answer: "非常欢迎您的反馈！您可以通过“个人中心-意见反馈”直接发送邮件，或联系我们的支持邮箱：riskycheng@gmail.com。我们会认真阅读每一封来信。"
                )
            }
        }
    }
    
    private var aboutMagneryContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            // App Identity Header
            VStack(alignment: .center, spacing: 16) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
                
                VStack(spacing: 6) {
                    Text("Magnery")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    
                    Text("记录每一份收藏的温度")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                        
                    HStack(spacing: 8) {
                        Text("Version 1.0.0")
                        Text("•")
                        Text("Build 20260111")
                    }
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            
            VStack(alignment: .leading, spacing: 16) {
                // Section 1: Intro
                AboutCard(title: "什么是 Magnery？", icon: "questionmark.circle.fill", color: .blue) {
                    Text("Magnery 是一款专为冰箱贴及小比例模型收藏家打造的数字化管理工具。我们利用尖端的 Vision AI 与 3D 重建技术，将您的实物收藏转化为生动的数字资产，让回忆在云端永存。")
                }
                
                // Section 2: Features
                AboutCard(title: "核心亮点", icon: "star.fill", color: .orange) {
                    VStack(alignment: .leading, spacing: 14) {
                        FeatureRow(icon: "camera.viewfinder", text: "全自动 AI 分割与物体识别", color: .blue)
                        FeatureRow(icon: "cube.transparent.fill", text: "2D 到 3D 快速建模与 AR 展示", color: .purple)
                        FeatureRow(icon: "sparkles.rectangle.stack", text: "多维度分类与地理标签轨迹", color: .orange)
                        FeatureRow(icon: "brain.headset", text: "智能科普对话与情感化互动", color: .green)
                    }
                    .padding(.top, 4)
                }
                
                // Section 3: Tech Stack
                AboutCard(title: "技术驱动", icon: "cpu.fill", color: .red) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Magnery 集成了业界领先的技术方案：")
                        Text("• **Vision SDK**: 实现毫秒级的端侧抠图与识别。")
                        Text("• **Hunyuan3D**: 腾讯混元大模型驱动的 3D 重建。")
                        Text("• **SiliconFlow**: 强大的 LLM 知识库与播报支持。")
                    }
                }
                
                // Section 4: Vision
                AboutCard(title: "我们的愿景", icon: "eye.fill", color: .purple) {
                    Text("连接现实与数字，赋予实物以灵魂。每一枚冰箱贴都承载着一段旅程。在 Magnery，我们不仅记录收藏，更在编织您跨越山海的人生印记。")
                }
                
                // Section 5: Community & Feedback
                AboutCard(title: "加入我们", icon: "person.2.fill", color: .indigo) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("如果您有任何创意想法，或想探索更多冰箱贴背后的故事，欢迎加入我们的社区。")
                        HStack(spacing: 20) {
                            Link(destination: URL(string: "mailto:riskycheng@gmail.com")!) {
                                Label("反馈建议", systemImage: "envelope.fill")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                    }
                }
                
                // Bottom Links / Footer
                VStack(spacing: 12) {
                    Divider()
                        .padding(.vertical, 8)
                        
                    Text("Made with ❤️ for Collectors")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                        
                    Text("© 2026 Magnery Team. All Rights Reserved.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
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

struct TOSBlock<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.system(size: 18))
                    .frame(width: 24)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            content
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .padding(.leading, 36)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 4)
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

struct FAQBlock: View {
    let question: String
    let answer: String
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    Text("Q:")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.orange)
                    
                    Text(question)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray.opacity(0.3))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    HStack(alignment: .top, spacing: 12) {
                        Text("A:")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.blue)
                        
                        Text(answer)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineSpacing(6)
                    }
                    .padding(16)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 4)
    }
}

struct AboutCard<Content: View>: View {
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
            HStack(spacing: 10) {
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
                .lineSpacing(6)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.025), radius: 10, x: 0, y: 5)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 4)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14, weight: .bold))
            }
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary.opacity(0.85))
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
