//
//  OverlayView.swift
//  Floato
//
//  Created by 杨飞 on 2025/6/15.
//

import SwiftUI
import AppKit

// 简化的计时器圆环
struct TimerRing: View {
    let progress: Double        // 0...1
    let tint: Color             // 直接收颜色
    
    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
            
            // 进度圆环
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
    }
}

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
    @State private var isCollapsed = false  // 强制展开状态
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
        VStack(spacing: 4) {
            // 获取当前任务颜色
            let currentTaskColor = store.currentIndex.flatMap { idx in
                store.items.indices.contains(idx) ? store.items[idx].category.color : nil
            } ?? .primary
            
            if case .running = phase {
                Text(timeString(secondsLeft))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(currentTaskColor)  // 使用任务颜色
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
                    .foregroundColor(currentTaskColor)  // 使用任务颜色
            }
        }
        .frame(width: 60, height: 60)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.3)) { 
                isCollapsed = false 
            }
        }
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
            
            // 番茄钟显示区域
            VStack(spacing: 12) {
                // 获取当前任务颜色
                let currentTaskColor = store.currentIndex.flatMap { idx in
                    store.items.indices.contains(idx) ? store.items[idx].category.color : nil
                } ?? .gray
                
                ZStack {
                    // 背景圆环
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    // 进度圆环 - 使用任务分类颜色
                    Circle()
                        .trim(from: 0, to: Double(secondsLeft) / Double(25 * 60))
                        .stroke(currentTaskColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: secondsLeft)
                }
                
                Text(timeString(secondsLeft))
                    .font(.title2)
                    .monospacedDigit()
                    .foregroundColor(.primary)
            }
            
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
                VStack(spacing: 8) {
                    // 获取当前任务颜色
                    let currentTaskColor = store.currentIndex.flatMap { idx in
                        store.items.indices.contains(idx) ? store.items[idx].category.color : nil
                    } ?? .gray
                    
                    ZStack {
                        // 背景圆环
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                            .frame(width: 70, height: 70)
                        
                        // 进度圆环 - 使用任务颜色
                        Circle()
                            .trim(from: 0, to: Double(secondsLeft) / Double(25 * 60))
                            .stroke(currentTaskColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 70, height: 70)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: secondsLeft)
                    }
                    
                    Text(timeString(secondsLeft))
                        .font(.title2)
                        .monospacedDigit()
                        .foregroundColor(.primary)
                    
                    // 小的颜色指示器，确认代码生效
                    Circle()
                        .fill(currentTaskColor)
                        .frame(width: 10, height: 10)
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
            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.items) { item in
                    HStack {
                        Image(systemName: item.isDone
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.category.color)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .strikethrough(item.isDone)
                                .font(.system(size: 13))
                            
                            HStack(spacing: 4) {
                                Image(systemName: item.category.iconName)
                                    .font(.system(size: 10))
                                Text(item.category.rawValue)
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(item.category.color.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Text("\(item.finishedPomos)/\(item.targetPomos)")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        // 带有分类颜色的毛玻璃背景
                        ZStack {
                            AdvancedVisualEffectView(
                                material: .sidebar,
                                blendingMode: .withinWindow,
                                state: .active,
                                cornerRadius: 8
                            )
                            
                            // 轻微的分类颜色叠加
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(item.category.color.opacity(0.1))
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(item.category.color.opacity(0.3), lineWidth: 0.5)
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxHeight: 150)
    }
    
    private func timeString(_ secs: Int) -> String {
        "\(secs / 60):" + String(format: "%02d", secs % 60)
    }
}