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
    @State private var showingHeatmap = false  // 热图窗口状态
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
                    
                    // 使用 markCurrentPomoDone() 来记录统计数据
                    let currentIdx = await MainActor.run {
                        return store.currentIndex
                    }
                    
                    await MainActor.run {
                        // 调用 markCurrentPomoDone 来正确记录统计数据
                        store.markCurrentPomoDone()
                        
                        // 如果任务完成了但还需要休息，暂时不要切换到下一个任务
                        // 等休息结束后再切换
                        if let idx = currentIdx, 
                           idx < store.items.count,
                           store.items[idx].isDone {
                            // 不管 advance() 是否改变了 currentIndex，都暂时恢复到当前任务
                            // 直到休息结束后再真正切换到下一个任务
                            store.currentIndex = idx
                        }
                    }
                    
                    // 发送完成通知
                    if let taskInfo = taskInfo {
                        await MainActor.run {
                            let hapticEnabled = UserDefaults.standard.bool(forKey: "hapticEnabled")
                            notifyDone(title: taskInfo.title, soundEnabled: true, hapticEnabled: hapticEnabled)
                        }
                    }
                    
                    // 检查是否是最后一个任务（检查刚刚完成的任务是否是最后一个）
                    let isLastTask = await MainActor.run {
                        // 使用原始的 currentIdx 来检查任务完成状态
                        if let idx = currentIdx,
                           idx < store.items.count,
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
                    if s <= 5 {
                        print("🛌 Break time: \(s) seconds left")
                    }
                    
                    // 当休息时间结束（到达0）时，切换到下一个任务
                    if s == 0 {
                        print("🛌 Break ended, advancing to next task")
                        await MainActor.run {
                            store.advance()
                        }
                    }
                }
            }
            
            // 计时器结束后，处理任务切换
            await MainActor.run {
                // 任务切换已经在 markCurrentPomoDone() 中处理过了
                // 这里只需要检查是否还有任务需要继续
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
                    Image(systemName: allTasksCompleted ? "hands.and.sparkles.fill" : "timer")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(allTasksCompleted ? Color(hex: "ef476f") : currentTaskColor)
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
            // 头部区域，包含热图按钮和折叠按钮
            HStack {
                // 左上角热图按钮
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingHeatmap.toggle()
                        if showingHeatmap {
                            WindowManager.shared.showHeatmapWindow(with: store)
                        } else {
                            WindowManager.shared.hideHeatmapWindow()
                        }
                    }
                }) {
                    Image(systemName: showingHeatmap ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .opacity(0.8)
                }
                .buttonStyle(.plain)
                .focusable(false)
                
                Spacer()
                
                // 右上角折叠按钮
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
                            Image(systemName: allTasksCompleted ? "hands.and.sparkles.fill" : "timer")
                                .font(.system(size: 24))
                                .foregroundColor(allTasksCompleted ? Color(hex: "ef476f") : .gray)
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

// 热图窗口组件
struct HeatmapWindow: View {
    @Environment(TodoStore.self) private var store
    @AppStorage("pomodoroMinutes") private var pomodoroMinutes = 25
    @State private var currentView: DailyStatsView = .heatmap
    let windowManager: WindowManager
    
    enum DailyStatsView: CaseIterable {
        case heatmap
        case barChart
        case pieChart
        case categoryBarChart
        
        var title: String {
            switch self {
            case .heatmap: return "日活动"
            case .barChart: return "本周统计"
            case .pieChart: return "今日分布"
            case .categoryBarChart: return "类型分布"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            Text(currentView.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            // 内容视图
            switch currentView {
            case .heatmap:
                DailyHeatmapView(
                    data: store.statisticsStore.getTodayHalfHourlyData(),
                    pomodoroMinutes: pomodoroMinutes
                )
                .frame(height: 100)
                
                // 图例
                HStack {
                    Text("少")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 3) {
                        ForEach(0..<5) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(heatmapColor(for: level))
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text("多")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
            case .barChart:
                WeeklyBarChartView(data: getWeeklyData())
                    .frame(height: 120)
                
            case .pieChart:
                DailyPieChartView(data: getTodayPieData())
                    .frame(height: 120)
                    
            case .categoryBarChart:
                CategoryBarChartView(data: getTodayCategoryData())
                    .frame(height: 120)
            }
        }
        .padding(16)
        .background(
            AdvancedVisualEffectView(
                material: .fullScreenUI,
                blendingMode: .behindWindow,
                state: .active,
                cornerRadius: 16
            )
        )
        .frame(width: 200, height: 200)
        .gesture(
            DragGesture()
                .onEnded { value in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if value.translation.width < -50 {
                            // 左滑切换到下一个视图
                            let allViews = DailyStatsView.allCases
                            if let currentIndex = allViews.firstIndex(of: currentView) {
                                let nextIndex = (currentIndex + 1) % allViews.count
                                currentView = allViews[nextIndex]
                            }
                        } else if value.translation.width > 50 {
                            // 右滑切换到上一个视图
                            let allViews = DailyStatsView.allCases
                            if let currentIndex = allViews.firstIndex(of: currentView) {
                                let previousIndex = (currentIndex - 1 + allViews.count) % allViews.count
                                currentView = allViews[previousIndex]
                            }
                        }
                    }
                }
        )
    }
    
    private func getWeeklyData() -> [DayData] {
        let calendar = Calendar.current
        var weeklyData: [DayData] = []
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let count = store.statisticsStore.getPomodoroCount(for: date)
                let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
                weeklyData.append(DayData(day: dayName, count: count, date: date))
            }
        }
        
        return weeklyData.reversed()
    }
    
    private func getTodayPieData() -> [PieData] {
        let todayData = store.statisticsStore.getTodayHalfHourlyData()
        var pieData: [PieData] = []
        
        // 按时间段分组
        let morningCount = (0..<24).compactMap { todayData[$0] }.reduce(0, +) // 0:00-11:59
        let afternoonCount = (24..<36).compactMap { todayData[$0] }.reduce(0, +) // 12:00-17:59
        let eveningCount = (36..<48).compactMap { todayData[$0] }.reduce(0, +) // 18:00-23:59
        
        if morningCount > 0 {
            pieData.append(PieData(name: "上午", count: morningCount, color: Color.blue))
        }
        if afternoonCount > 0 {
            pieData.append(PieData(name: "下午", count: afternoonCount, color: Color.orange))
        }
        if eveningCount > 0 {
            pieData.append(PieData(name: "晚上", count: eveningCount, color: Color.purple))
        }
        
        return pieData
    }
    
    private func getTodayCategoryData() -> [CategoryData] {
        let categoryData = store.statisticsStore.getTodayCategoryData()
        var result: [CategoryData] = []
        
        for category in TodoStore.TaskCategory.allCases {
            let count = categoryData[category] ?? 0
            if count > 0 {
                result.append(CategoryData(category: category, count: count))
            }
        }
        
        return result
    }
    
    struct DayData {
        let day: String
        let count: Int
        let date: Date
    }
    
    struct PieData {
        let name: String
        let count: Int
        let color: Color
    }
    
    struct CategoryData {
        let category: TodoStore.TaskCategory
        let count: Int
    }
    
    private func heatmapColor(for level: Int) -> Color {
        switch level {
        case 0: return Color.gray.opacity(0.1)
        case 1: return Color.green.opacity(0.3)
        case 2: return Color.green.opacity(0.5)
        case 3: return Color.green.opacity(0.7)
        case 4: return Color.green.opacity(0.9)
        default: return Color.green
        }
    }
}

// 本周条形图组件
struct WeeklyBarChartView: View {
    let data: [HeatmapWindow.DayData]
    
    var body: some View {
        let maxCount = data.map { $0.count }.max() ?? 1
        
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(data, id: \.day) { dayData in
                    VStack(spacing: 4) {
                        // 条形图
                        Rectangle()
                            .fill(barColor(for: dayData.count, max: maxCount))
                            .frame(width: 20, height: max(4, CGFloat(dayData.count) / CGFloat(maxCount) * 60))
                            .cornerRadius(2)
                        
                        // 天数标签
                        Text(dayData.day)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 数值标签
            HStack(spacing: 6) {
                ForEach(data, id: \.day) { dayData in
                    Text("\(dayData.count)")
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .frame(width: 20)
                }
            }
        }
    }
    
    private func barColor(for count: Int, max: Int) -> Color {
        let ratio = Double(count) / Double(max)
        if count == 0 { return Color.gray.opacity(0.2) }
        if ratio <= 0.3 { return Color.blue.opacity(0.5) }
        if ratio <= 0.6 { return Color.blue.opacity(0.7) }
        return Color.blue.opacity(0.9)
    }
}

// 今日饼图组件
struct DailyPieChartView: View {
    let data: [HeatmapWindow.PieData]
    
    var body: some View {
        if data.isEmpty {
            VStack {
                Image(systemName: "clock")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("今日暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 12) {
                // 简化的饼图
                HStack(spacing: 12) {
                    // 左侧饼图
                    ZStack {
                        ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                            PieSlice(
                                startAngle: startAngle(for: index),
                                endAngle: endAngle(for: index),
                                color: item.color
                            )
                        }
                    }
                    .frame(width: 60, height: 60)
                    .background(Color.clear)
                    .clipped()
                    
                    // 右侧图例
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(data, id: \.name) { item in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 8, height: 8)
                                
                                Text(item.name)
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(item.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // 总计
                Text("总计: \(data.reduce(0) { $0 + $1.count }) 个")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var totalCount: Int {
        data.reduce(0) { $0 + $1.count }
    }
    
    private func startAngle(for index: Int) -> Angle {
        let previousItems = data.prefix(index)
        let previousSum = previousItems.reduce(0) { $0 + $1.count }
        return Angle(degrees: Double(previousSum) / Double(totalCount) * 360 - 90)
    }
    
    private func endAngle(for index: Int) -> Angle {
        let previousItems = data.prefix(index + 1)
        let sum = previousItems.reduce(0) { $0 + $1.count }
        return Angle(degrees: Double(sum) / Double(totalCount) * 360 - 90)
    }
}

// 饼图扇形
struct PieSlice: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    
    var body: some View {
        Path { path in
            let center = CGPoint(x: 30, y: 30)
            let radius: CGFloat = 25
            
            path.move(to: center)
            path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            path.closeSubpath()
        }
        .fill(color.opacity(0.9))
        .shadow(radius: 0)
        .drawingGroup()
    }
}

// 类型分布条形图组件
struct CategoryBarChartView: View {
    let data: [HeatmapWindow.CategoryData]
    
    var body: some View {
        if data.isEmpty {
            VStack {
                Image(systemName: "chart.bar")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("今日暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let maxCount = data.map { $0.count }.max() ?? 1
            
            VStack(spacing: 8) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(data, id: \.category) { categoryData in
                        VStack(spacing: 4) {
                            // 条形图
                            Rectangle()
                                .fill(categoryData.category.color.opacity(0.8))
                                .frame(width: 24, height: max(8, CGFloat(categoryData.count) / CGFloat(maxCount) * 60))
                                .cornerRadius(3)
                            
                            // 类型图标
                            Image(systemName: categoryData.category.iconName)
                                .font(.caption2)
                                .foregroundColor(categoryData.category.color)
                                .frame(width: 24)
                        }
                    }
                }
                
                // 数值标签
                HStack(spacing: 8) {
                    ForEach(data, id: \.category) { categoryData in
                        Text("\(categoryData.count)")
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .frame(width: 24)
                    }
                }
                
                // 类型名称
                HStack(spacing: 8) {
                    ForEach(data, id: \.category) { categoryData in
                        Text(categoryData.category.rawValue)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
    }
}

// 日热力图组件 - 显示48个半小时区域
struct DailyHeatmapView: View {
    let data: [Int: Int]
    let pomodoroMinutes: Int
    
    var body: some View {
        VStack(spacing: 2) {
            // 重新排列成12列4行的布局
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<12, id: \.self) { col in
                        let period = row * 12 + col
                        let count = data[period] ?? 0
                        let level = calculateLevel(count: count)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(contributionColor(for: level))
                            .frame(width: 12, height: 12)
                            .help(toolTip(for: period, count: count))
                    }
                }
            }
        }
    }
    
    private func calculateLevel(count: Int) -> Int {
        // 基于番茄钟设置时长和30分钟时段计算等级
        let maxPomodorosPerPeriod = 30.0 / Double(pomodoroMinutes)
        let ratio = Double(count) / maxPomodorosPerPeriod
        
        if count == 0 { return 0 }
        if ratio <= 0.25 { return 1 }
        if ratio <= 0.5 { return 2 }
        if ratio <= 0.75 { return 3 }
        return 4
    }
    
    private func contributionColor(for level: Int) -> Color {
        switch level {
        case 0: return Color.gray.opacity(0.1)
        case 1: return Color.green.opacity(0.3)
        case 2: return Color.green.opacity(0.5)
        case 3: return Color.green.opacity(0.7)
        case 4: return Color.green.opacity(0.9)
        default: return Color.green
        }
    }
    
    private func toolTip(for period: Int, count: Int) -> String {
        let hour = period / 2
        let minute = (period % 2) * 30
        let endMinute = minute + 30
        let endHour = endMinute >= 60 ? hour + 1 : hour
        let displayEndMinute = endMinute >= 60 ? 0 : endMinute
        
        return String(format: "%02d:%02d-%02d:%02d: %d 个番茄钟", 
                     hour, minute, endHour, displayEndMinute, count)
    }
}