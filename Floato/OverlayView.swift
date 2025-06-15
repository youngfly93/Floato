//
//  OverlayView.swift
//  Floato
//
//  Created by 杨飞 on 2025/6/15.
//

import SwiftUI
import AppKit

// 高级毛玻璃效果视图
struct AdvancedVisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State
    let cornerRadius: CGFloat
    
    init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow,
        state: NSVisualEffectView.State = .active,
        cornerRadius: CGFloat = 16
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
        self.cornerRadius = cornerRadius
    }
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.wantsLayer = true
        
        // 关键：直接在 NSVisualEffectView 层设置圆角
        if let layer = view.layer {
            layer.cornerRadius = cornerRadius
            layer.masksToBounds = true
            layer.cornerCurve = .continuous
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        
        // 更新圆角
        if let layer = nsView.layer {
            layer.cornerRadius = cornerRadius
            layer.masksToBounds = true
            layer.cornerCurve = .continuous
        }
    }
}

// 毛玻璃卡片组件 - 使用原生 NSVisualEffectView
struct FrostedCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // 原生毛玻璃背景 - 直接应用圆角，避免 mask 造成的方形边界
            AdvancedVisualEffectView(
                material: .hudWindow,
                blendingMode: .withinWindow,
                state: .active,
                cornerRadius: cornerRadius
            )
            
            // 内容层
            content
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        // 外部阴影保持圆角形状
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            // 细微的白色边框增强视觉层次
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

struct OverlayView: View {
    @Environment(TodoStore.self) private var store
    @State private var secondsLeft = 0
    @State private var phase: PomodoroClock.Phase = .idle
    @State private var isCollapsed = false
    private let clock = PomodoroClock()
    
    var body: some View {
        Group {
            if isCollapsed {
                collapsedView
            } else {
                expandedView
            }
        }
        .task(id: store.currentIndex) {
            guard store.currentIndex != nil else { return }
            for await phase in await clock.start() {
                self.phase = phase
                if case .running(let s) = phase { secondsLeft = s }
                if case .breakTime = phase {
                    await MainActor.run {
                        if let idx = store.currentIndex {
                            notifyDone(title: store.items[idx].title)
                        }
                        store.markCurrentPomoDone()
                    }
                    await clock.stop()
                }
            }
        }
    }
    
    // 折叠状态 - 小方块只显示时间
    private var collapsedView: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.3)) { isCollapsed = false } }) {
            VStack(spacing: 4) {
                if case .running = phase {
                    Text(timeString(secondsLeft))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                } else {
                    Image(systemName: {
                        switch phase {
                        case .breakTime:
                            return "cup.and.saucer.fill"
                        default:
                            return "timer"
                        }
                    }())
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .frame(width: 60, height: 60)
        }
        .buttonStyle(.plain)
        .onAppear {
            // 更新窗口圆角为小尺寸
            if let window = NSApplication.shared.keyWindow as? FloatingPanel {
                window.updateCornerRadius(18)
            }
        }
    }
    
    // 展开状态 - 完整悬浮窗
    private var expandedView: some View {
        VStack(spacing: 12) {
            // 头部区域，包含折叠按钮
            HStack {
                Spacer()
                Button(action: { withAnimation(.easeInOut(duration: 0.3)) { isCollapsed = true } }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .opacity(0.8)
                }
                .buttonStyle(.plain)
            }
            
            header
            
            Divider()
                .opacity(0.3)
            
            taskList
        }
        .padding(20)
        .frame(minWidth: 220, maxWidth: .infinity,
               minHeight: 260, maxHeight: .infinity)
        .onAppear {
            // 更新窗口圆角为正常尺寸
            if let window = NSApplication.shared.keyWindow as? FloatingPanel {
                window.updateCornerRadius(16)
            }
        }
    }
    
    private var header: some View {
        switch phase {
        case .running:
            return AnyView(
                VStack {
                    ProgressView(value: Double(secondsLeft),
                                 total: 25*60)
                        .progressViewStyle(.circular)
                    Text(timeString(secondsLeft))
                        .font(.title2).monospacedDigit()
                }
            )
        case .breakTime:
            return AnyView(Text("Break ☕️").font(.title2))
        default:
            return AnyView(Text("Ready 🍅").font(.title2))
        }
    }
    
    private var taskList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(store.items) { item in
                    HStack {
                        Image(systemName: item.isDone
                              ? "checkmark.circle.fill" : "circle")
                        Text(item.title)
                            .strikethrough(item.isDone)
                        Spacer()
                        Text("\(item.finishedPomos)/\(item.targetPomos)")
                            .font(.caption2).monospacedDigit()
                    }
                }
            }
        }
        .frame(maxHeight: 150)
    }
    
    private func timeString(_ secs: Int) -> String {
        "\(secs / 60):" + String(format: "%02d", secs % 60)
    }
}