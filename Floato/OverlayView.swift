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
    @State private var secondsLeft = 0  // 初始化为0，显示空圆环
    @State private var breakSecondsLeft = 5 * 60
    @State private var phase: PomodoroClock.Phase = .idle
    @State private var isCollapsed = false  // 强制展开状态
    @AppStorage("pomodoroMinutes") private var pomodoroMinutes = 25
    @Namespace private var animation
    private let clock = PomodoroClock()
    
    var body: some View {
        Group {
            if isCollapsed {
                collapsedView
                    .transition(.opacity.combined(with: .scale))
            } else {
                expandedView
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isCollapsed)
        .onChange(of: pomodoroMinutes) { _, newValue in
            // 当番茄钟设置改变时，如果处于空闲状态且没有任务，保持显示 0:00
            if case .idle = phase, store.currentIndex == nil {
                secondsLeft = 0
            }
        }
        .task(id: store.currentIndex) {
            guard store.currentIndex != nil else { 
                // 如果没有当前任务（比如重置后），停止计时器并重置状态
                await clock.stop()
                phase = .idle
                secondsLeft = 0  // 重置后显示 0:00
                breakSecondsLeft = 5 * 60
                return 
            }
            await clock.updateWorkDuration(minutes: pomodoroMinutes)
            var hasCompletedWork = false
            var hasNotifiedWorkDone = false
            
            // 先不跳过休息，正常启动
            var isWorkCompleted = false
            
            for await phase in await clock.start(skipBreak: false) {
                self.phase = phase
                
                // 处理工作阶段
                if case .running(let s) = phase { 
                    secondsLeft = s
                    if s == 0 {
                        isWorkCompleted = true
                    }
                }
                
                // 处理休息阶段
                if case .breakTime(let s) = phase { 
                    breakSecondsLeft = s
                    
                    // 只在第一次进入休息时发送通知
                    if !hasNotifiedWorkDone {
                        hasNotifiedWorkDone = true
                        
                        // 发送通知
                        await MainActor.run {
                            if let idx = store.currentIndex {
                                let hapticEnabled = UserDefaults.standard.bool(forKey: "hapticEnabled")
                                notifyDone(title: store.items[idx].title, soundEnabled: true, hapticEnabled: hapticEnabled)
                            }
                        }
                        
                        // 检查是否是最后一个任务
                        let isLastTask = await MainActor.run {
                            // 这时候当前任务的finishedPomos还没增加，所以需要预判
                            guard let idx = store.currentIndex else { return false }
                            let willBeCompleted = store.items[idx].finishedPomos + 1 >= store.items[idx].targetPomos
                            if willBeCompleted {
                                // 检查后续是否还有未完成的任务
                                for i in (idx + 1)..<store.items.count {
                                    if !store.items[i].isDone {
                                        return false
                                    }
                                }
                                return true
                            }
                            return false
                        }
                        
                        if isLastTask {
                            // 如果是最后一个任务，立即退出，不进行休息
                            self.phase = .idle
                            break
                        }
                    }
                }
            }
            
            
            // 只有在整个循环（工作+休息）结束后才标记任务完成并切换
            if !hasCompletedWork {
                hasCompletedWork = true
                await MainActor.run {
                    store.markCurrentPomoDone()
                }
            }
        }
        .onChange(of: pomodoroMinutes) { _, newValue in
            Task {
                await clock.updateWorkDuration(minutes: newValue)
            }
        }
        .focusable(false)
    }
    
    // 折叠状态 - 小方块只显示时间
    private var collapsedView: some View {
        VStack(spacing: 4) {
            let currentTaskColor = store.currentIndex.flatMap { idx in
                store.items.indices.contains(idx) ? store.items[idx].category.color : nil
            } ?? .primary
            
            switch phase {
            case .running:
                Text(timeString(secondsLeft))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(currentTaskColor)
            case .breakTime:
                VStack(spacing: 2) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.orange)
                    Text(timeString(breakSecondsLeft))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }
            default:
                let allTasksCompleted = !store.items.isEmpty && store.items.allSatisfy { $0.isDone }
                let hasNoTasks = store.items.isEmpty
                
                if hasNoTasks {
                    Text("0:00")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                } else {
                    Image(systemName: allTasksCompleted ? "checkmark.circle.fill" : "timer")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(allTasksCompleted ? .green : currentTaskColor)
                }
            }
        }
        .frame(width: 80, height: 80)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isCollapsed = false
            }
        }
    }
    
    // 展开状态 - 完整悬浮窗
    private var expandedView: some View {
        VStack(spacing: 0) {
            // 头部区域，包含折叠按钮
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isCollapsed = true
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .opacity(0.8)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .frame(height: 40)
            
            // 番茄钟显示区域
            VStack(spacing: 8) {
                switch phase {
                case .running:
                    let currentTaskColor = store.currentIndex.flatMap { idx in
                        store.items.indices.contains(idx) ? store.items[idx].category.color : nil
                    } ?? .gray
                    
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                                .frame(width: 50, height: 50)
                            
                            Circle()
                                .trim(from: 0, to: Double(secondsLeft) / Double(pomodoroMinutes * 60))
                                .stroke(currentTaskColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 50, height: 50)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.3), value: secondsLeft)
                        }
                        
                        Text(timeString(secondsLeft))
                            .font(.title3)
                            .monospacedDigit()
                            .foregroundColor(.primary)
                    }
                    
                case .breakTime:
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                                .frame(width: 50, height: 50)
                            
                            Circle()
                                .trim(from: 0, to: Double(breakSecondsLeft) / Double(5 * 60))
                                .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 50, height: 50)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.3), value: breakSecondsLeft)
                        }
                        
                        Text("☕️ 休息")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text(timeString(breakSecondsLeft))
                            .font(.title3)
                            .monospacedDigit()
                            .foregroundColor(.orange)
                    }
                    
                default:
                    VStack(spacing: 4) {
                        let allTasksCompleted = !store.items.isEmpty && store.items.allSatisfy { $0.isDone }
                        let hasNoTasks = store.items.isEmpty
                        
                        if hasNoTasks {
                            // 没有任务时显示空圆环和0:00
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                                    .frame(width: 50, height: 50)
                            }
                            
                            Text("0:00")
                                .font(.title3)
                                .monospacedDigit()
                                .foregroundColor(.gray)
                        } else {
                            // 有任务时显示状态图标
                            Image(systemName: allTasksCompleted ? "checkmark.circle.fill" : "timer")
                                .font(.system(size: 24))
                                .foregroundColor(allTasksCompleted ? .green : .gray)
                            
                            Text(allTasksCompleted ? "🎉 完成" : "准备")
                                .font(.caption)
                                .foregroundColor(allTasksCompleted ? .green : .gray)
                        }
                    }
                }
            }
            .frame(height: 100)
            
            Divider()
                .opacity(0.3)
                .padding(.horizontal, 20)
            
            VStack {
                taskList
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 260, height: 300)
    }
    
    
    
    private var taskList: some View {
        VStack(spacing: 4) {
            ForEach(store.items.prefix(2), id: \.id) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(item.category.color)
                        .frame(width: 8, height: 8)
                    
                    Text(item.title)
                        .font(.system(size: 18, weight: .medium))
                        .lineLimit(1)
                        .strikethrough(item.isDone, color: .secondary)
                        .foregroundStyle(item.isDone ? .secondary : .primary)
                    
                    Spacer()
                    
                    Text("\(item.finishedPomos)/\(item.targetPomos)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(item.category.color.opacity(0.1))
                )
            }
        }
    }
    
    private func timeString(_ secs: Int) -> String {
        "\(secs / 60):" + String(format: "%02d", secs % 60)
    }
    
    private func updateWindowSize(collapsed: Bool) {
        // 简化实现，避免窗口查找可能导致的崩溃
        // 圆角更新会在窗口大小变化时自动处理
    }
}