import SwiftUI
import Combine

struct ThreeDProgressView: View {
    let progress: Double
    let status: String
    
    @State private var rotation: Double = 0
    @State private var cubeRotation: Double = 0
    @State private var scanOffset: CGFloat = -1.0
    @State private var hintIndex = 0
    
    let hints = [
        "正在提取特征点...",
        "分析表面纹理中...",
        "正在合成几何网格...",
        "计算 PBR 材质属性...",
        "优化模型拓扑结构...",
        "正在生成 USDZ 文件..."
    ]
    
    let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 28) {
            // Animated Icon Section
            ZStack {
                // Background Glowing Aura
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                // Outer rotating "Technical" ring with segments
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    
                    ForEach(0..<4) { i in
                        Circle()
                            .trim(from: CGFloat(i) * 0.25, to: CGFloat(i) * 0.25 + 0.1)
                            .stroke(
                                LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                    }
                }
                .frame(width: 110, height: 110)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
                
                // Progress ring with Gradient & Glow
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 6)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .cyan, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .shadow(color: .cyan.opacity(0.5), radius: 5)
                }
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: progress)
                
                // Rotating 3D Cube
                Image(systemName: "cube.transparent")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundColor(.white)
                    .rotation3DEffect(.degrees(cubeRotation), axis: (x: 1, y: 1, z: 0))
                    .onAppear {
                        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                            cubeRotation = 360
                        }
                    }
                
                // Scanning Line Effect
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .cyan.opacity(0.5), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 100, height: 2)
                    .offset(y: scanOffset * 40)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                            scanOffset = 1.0
                        }
                    }
            }
            .padding(.top, 10)
            
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("AI 空间扫描中")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .tracking(2)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 6) {
                    Text(status)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .frame(height: 40)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 4, height: 4)
                        
                        Text(hints[hintIndex])
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                            .id("hint_\(hintIndex)")
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(32)
        .background(
            ZStack {
                BlurView(style: .systemUltraThinMaterialDark)
                
                // Animated background "Energy" pulses
                Circle()
                    .stroke(Color.cyan.opacity(0.1), lineWidth: 2)
                    .scaleEffect(1.0 + (progress * 0.2))
                    .opacity(0.5)
            }
        )
        .cornerRadius(32)
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 40, x: 0, y: 20)
        .onReceive(timer) { _ in
            withAnimation {
                hintIndex = (hintIndex + 1) % hints.count
            }
        }
    }
}
