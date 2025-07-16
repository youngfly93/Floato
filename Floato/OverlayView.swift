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
        material: NSVisualEffectView.Material = .fullScreenUI,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
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
            // 真正的 Liquid Glass 效果
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.25), location: 0.0),
                            .init(color: Color.white.opacity(0.1), location: 0.5),
                            .init(color: Color.clear, location: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
            
            // 内容层
            content
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        // 多层玻璃边框效果
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.6), location: 0.0),
                            .init(color: Color.white.opacity(0.2), location: 0.3),
                            .init(color: Color.clear, location: 0.7),
                            .init(color: Color.white.opacity(0.1), location: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        // 深度阴影系统
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 12)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
            print("⏰ Task triggered with currentIndex: \(store.currentIndex?.description ?? "nil")")
            
            guard store.currentIndex != nil else { 
                // 如果没有当前任务（比如重置后），停止计时器并重置状态
                print("🛑 No current task, stopping timer")
                await clock.stop()
                phase = .idle
                secondsLeft = 0  // 重置后显示 0:00
                breakSecondsLeft = 5 * 60
                return 
            }
            
            // 更新工作时长设置
            await clock.updateWorkDuration(minutes: pomodoroMinutes)
            
            // 永远不跳过休息时间，除非这是真正的最后一个任务且没有其他待完成的任务
            let isLastTask = false
            
            var hasCompletedCurrentTask = false
            
            for await phase in await clock.start(skipBreak: isLastTask) {
                self.phase = phase
                
                // 处理工作阶段
                if case .running(let s) = phase { 
                    secondsLeft = s
                    if s <= 5 { // 只在最后5秒打印，避免太多输出
                        print("⏱️ Work phase: \(s) seconds left")
                    }
                }
                
                // 检查工作阶段是否结束（倒计时到0）
                if case .running(let s) = phase, s == 0 && !hasCompletedCurrentTask {
                    print("🎯 Work phase completed! s=\(s), hasCompleted=\(hasCompletedCurrentTask)")
                    hasCompletedCurrentTask = true
                    
                    // 先获取当前任务信息，然后只更新 finishedPomos，不调用 advance()
                    let taskInfo = await MainActor.run { () -> (title: String, index: Int)? in
                        if let idx = store.currentIndex {
                            return (title: store.items[idx].title, index: idx)
                        }
                        return nil
                    }
                    
                    // 只增加完成的番茄钟数量，但不调用 advance()
                    await MainActor.run {
                        if let idx = store.currentIndex {
                            print("📝 Marking pomo done for task \(idx): \(store.items[idx].finishedPomos) -> \(store.items[idx].finishedPomos + 1)")
                            store.items[idx].finishedPomos += 1
                            
                            if store.items[idx].finishedPomos >= store.items[idx].targetPomos {
                                print("✅ Task \(idx) completed: \(store.items[idx].finishedPomos)/\(store.items[idx].targetPomos)")
                                store.items[idx].isDone = true
                                // 注意：这里不调用 advance()，在休息结束后再调用
                            } else {
                                print("🔄 Task \(idx) still in progress: \(store.items[idx].finishedPomos)/\(store.items[idx].targetPomos)")
                            }
                            store.save()
                        }
                    }
                    
                    // 发送完成通知
                    if let taskInfo = taskInfo {
                        await MainActor.run {
                            let hapticEnabled = UserDefaults.standard.bool(forKey: "hapticEnabled")
                            notifyDone(title: taskInfo.title, soundEnabled: true, hapticEnabled: hapticEnabled)
                        }
                    }
                    
                    // 检查是否是最后一个任务（任务完成且没有其他未完成的任务）
                    let isLastTask = await MainActor.run {
                        if let idx = store.currentIndex,
                           store.items[idx].isDone {
                            // 检查是否还有其他未完成的任务
                            for i in 0..<store.items.count {
                                if i != idx && !store.items[i].isDone {
                                    return false
                                }
                            }
                            return true
                        }
                        return false
                    }
                    
                    if isLastTask {
                        print("✅ Last task completed, skipping break")
                        // 最后一个任务完成，跳过休息，直接结束
                        self.phase = .idle
                        await MainActor.run {
                            store.advance() // 这会设置 currentIndex = nil
                        }
                        break
                    }
                    
                    print("🔄 Work completed, will advance to next task after break")
                }
                
                // 处理休息阶段
                if case .breakTime(let s) = phase { 
                    breakSecondsLeft = s
                }
            }
            
            // 计时器结束后，处理任务切换
            await MainActor.run {
                // 如果当前任务已完成，切换到下一个任务
                if let idx = store.currentIndex, store.items[idx].isDone {
                    print("🔄 Current task is done, advancing to next task")
                    store.advance()
                }
                
                // 检查是否还有任务需要继续
                if store.currentIndex != nil {
                    print("🔄 More tasks available, will restart automatically")
                } else {
                    print("✅ All tasks completed")
                    self.phase = .idle
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
                sevenSegmentTimeView(secondsLeft, color: currentTaskColor, fontSize: 32)
            case .breakTime:
                VStack(spacing: 2) {
                    Image(systemName: "figure.cooldown")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "b0d8ff"))
                    sevenSegmentTimeView(breakSecondsLeft, color: Color(hex: "b0d8ff"), fontSize: 18)
                }
            default:
                let allTasksCompleted = !store.items.isEmpty && store.items.allSatisfy { $0.isDone }
                let hasNoTasks = store.items.isEmpty
                
                if hasNoTasks {
                    sevenSegmentTimeView(0, color: .gray, fontSize: 24)
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
    
    // 计算动态高度
    private var dynamicHeight: CGFloat {
        if store.items.isEmpty {
            return 300 // 没有任务时返回固定高度
        }
        
        let baseHeight: CGFloat = 130 // 头部 + 番茄钟显示 + 分隔线的基础高度
        let taskRowHeight: CGFloat = 52 // 每个任务行的高度（包括spacing）
        let bottomPadding: CGFloat = 20
        let taskCount = store.items.count
        return baseHeight + CGFloat(taskCount) * taskRowHeight + bottomPadding
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
            .padding(.top, 2)
            .frame(height: 24)
            
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
                        
                        sevenSegmentTimeView(secondsLeft, color: .primary, fontSize: 18)
                    }
                    
                case .breakTime:
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                                .frame(width: 50, height: 50)
                            
                            Circle()
                                .trim(from: 0, to: Double(breakSecondsLeft) / Double(5 * 60))
                                .stroke(Color(hex: "b0d8ff"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 50, height: 50)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.3), value: breakSecondsLeft)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "figure.cooldown")
                                .font(.caption)
                                .foregroundColor(Color(hex: "b0d8ff"))
                            Text("休息")
                                .font(.caption)
                                .foregroundColor(Color(hex: "b0d8ff"))
                        }
                        
                        sevenSegmentTimeView(breakSecondsLeft, color: Color(hex: "b0d8ff"), fontSize: 18)
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
                            
                            sevenSegmentTimeView(0, color: .gray, fontSize: 18)
                        } else {
                            // 有任务时显示状态图标
                            Image(systemName: allTasksCompleted ? "checkmark.circle.fill" : "timer")
                                .font(.system(size: 24))
                                .foregroundColor(allTasksCompleted ? .green : .gray)
                            
                            HStack(spacing: 4) {
                                if allTasksCompleted {
                                    Image(systemName: "party.popper.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    Text("完成")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "clock")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("准备")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 100)
            
            Divider()
                .opacity(0.3)
                .padding(.horizontal, 20)
            
            if !store.items.isEmpty {
                VStack {
                    taskList
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else {
                Spacer()
                    .frame(height: 150)
            }
        }
        .frame(width: 220, height: dynamicHeight)
        .animation(.easeInOut(duration: 0.3), value: store.items.count)
    }
    
    
    
    private var taskList: some View {
        VStack(spacing: 8) {
            ForEach(store.items, id: \.id) { item in
                taskRowView(for: item)
            }
        }
    }
    
    private func taskRowView(for item: TodoStore.Item) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(item.category.color)
                .frame(width: 8, height: 8)
            
            Text(item.title)
                .font(.system(size: 16, weight: item.isDone ? .regular : .semibold))
                .italic(item.isDone)
                .lineLimit(1)
                .strikethrough(item.isDone, color: item.isDone ? .secondary.opacity(0.6) : .secondary)
                .foregroundColor(item.isDone ? .secondary.opacity(0.7) : .primary)
            
            Spacer()
            
            Text("\(item.finishedPomos)/\(item.targetPomos)")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(taskRowBackground(for: item))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }
    
    private func taskRowBackground(for item: TodoStore.Item) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(item.category.color.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 0.5)
    }
    
    private func timeString(_ secs: Int) -> String {
        "\(secs / 60):" + String(format: "%02d", secs % 60)
    }
    
    // 7段数码管样式的时间显示
    private func sevenSegmentTimeView(_ secs: Int, color: Color = .primary, fontSize: CGFloat = 18) -> some View {
        let customFont = Font.custom("7-Segment", size: fontSize)
        
        return Text(timeString(secs))
            .font(customFont)
            .foregroundColor(color)
            .shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 0)
            .overlay(
                // 添加数码管效果的背景发光
                Text(timeString(secs))
                    .font(customFont)
                    .foregroundColor(color.opacity(0.15))
                    .blur(radius: 2)
            )
    }
    
    private func updateWindowSize(collapsed: Bool) {
        // 简化实现，避免窗口查找可能导致的崩溃
        // 圆角更新会在窗口大小变化时自动处理
    }
}