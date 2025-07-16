//
//  SettingsView.swift
//  Floato
//
//  Created by 杨飞 on 2025/6/15.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(TodoStore.self) private var store
    @State private var title = ""
    @State private var pomos = 1
    @State private var selectedCategory: TodoStore.TaskCategory = .work
    @State private var showingResetAlert = false
    @State private var showingStatistics = false
    @AppStorage("pomodoroMinutes") private var pomodoroMinutes = 25
    @AppStorage("selectedSound") private var selectedSound = "glass"
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    var body: some View {
        Form {
            Section("新任务") {
                TextField("标题", text: $title)
                
                Stepper(value: $pomos, in: 1...8) {
                    Text("番茄数: \(pomos)")
                }
                
                Picker("分类", selection: $selectedCategory) {
                    ForEach(TodoStore.TaskCategory.allCases, id: \.self) { category in
                        HStack {
                            Image(systemName: category.iconName)
                                .foregroundColor(category.color)
                            Text(category.rawValue)
                        }
                        .tag(category)
                    }
                }
                .pickerStyle(.menu)
                
                Button("添加") {
                    guard !title.isEmpty else { return }
                    store.add(title: title, pomos: pomos, category: selectedCategory)
                    title = ""
                    pomos = 1
                    selectedCategory = .work
                }
                .disabled(title.isEmpty)
            }
            Section("列表") {
                ForEach(store.items) { item in
                    HStack {
                        Image(systemName: item.category.iconName)
                            .foregroundColor(item.category.color)
                            .frame(width: 16)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .strikethrough(item.isDone)
                            Text(item.category.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(item.finishedPomos)/\(item.targetPomos)")
                            .font(.caption2)
                            .monospacedDigit()
                    }
                }
                .onDelete { indexSet in
                    store.items.remove(atOffsets: indexSet)
                    store.save()
                }
            }
            
            Section("番茄钟设置") {
                HStack {
                    Text("时长:")
                    TextField("分钟", value: $pomodoroMinutes, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .onChange(of: pomodoroMinutes) { _, newValue in
                            // 限制范围为 1-60 分钟
                            if newValue < 1 {
                                pomodoroMinutes = 1
                            } else if newValue > 60 {
                                pomodoroMinutes = 60
                            }
                        }
                    Text("分钟")
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("完成提示音:")
                        .font(.subheadline)
                    Picker("", selection: $selectedSound) {
                        ForEach(SoundType.allCases, id: \.self) { sound in
                            Text(sound.rawValue).tag(sound.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedSound) { _, newSound in
                        // 预览选中的声音
                        previewSound(SoundType(rawValue: newSound) ?? .glass)
                    }
                }
                
                Toggle("震动反馈", isOn: $hapticEnabled)
                    .toggleStyle(.switch)
            }
            
            Section("操作") {
                Button("查看统计") {
                    showingStatistics = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.blue)
                
                Button("重置所有任务") {
                    // 直接执行重置，不使用对话框
                    store.items.removeAll()
                    store.currentIndex = nil
                    store.save()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
                
                Button("退出程序") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 260, height: 450)
        .sheet(isPresented: $showingStatistics) {
            StatisticsView()
        }
    }
    
    private func previewSound(_ soundType: SoundType) {
        switch soundType {
        case .none:
            break
        case .beep:
            NSSound.beep()
        default:
            if let soundName = soundType.soundName,
               let sound = NSSound(named: NSSound.Name(soundName)) {
                sound.play()
            }
        }
    }
}

// MARK: - Statistics View

struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TodoStore.self) private var todoStore
    
    var body: some View {
        VStack(spacing: 20) {
            // 头部标题
            HStack {
                Text("番茄钟统计")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            // 统计摘要卡片
            let summary = todoStore.statisticsStore.getStatisticsSummary()
            HStack(spacing: 16) {
                StatCard(title: "今日", value: summary.today, color: .blue)
                StatCard(title: "本周", value: summary.thisWeek, color: .green)
                StatCard(title: "本月", value: summary.thisMonth, color: .orange)
                StatCard(title: "总计", value: summary.total, color: .purple)
            }
            .padding(.horizontal)
            
            // 热力图区域
            VStack(alignment: .leading, spacing: 12) {
                Text("最近一年活动")
                    .font(.headline)
                    .padding(.horizontal)
                
                // 临时使用简单的网格视图替代ContributionChart
                // 等SPM依赖添加后可以替换为真正的ContributionChart
                HeatmapGridView(data: todoStore.statisticsStore.getHeatmapData())
                    .frame(height: 120)
                    .padding(.horizontal)
                
                // 图例
                HStack {
                    Text("少")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 3) {
                        ForEach(0..<5) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(heatmapColor(for: level))
                                .frame(width: 12, height: 12)
                        }
                    }
                    
                    Text("多")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(width: 600, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
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

// 统计卡片组件
struct StatCard: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// 临时的热力图网格视图
struct HeatmapGridView: View {
    let data: [Date: Int]
    
    var body: some View {
        let calendar = Calendar.current
        let weeks = generateWeeks()
        
        VStack(spacing: 3) {
            ForEach(0..<weeks.count, id: \.self) { weekIndex in
                HStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let dayOffset = weekIndex * 7 + dayIndex
                        if let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) {
                            let count = data[date] ?? 0
                            let level = min(count, 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(heatmapColor(for: level))
                                .frame(width: 12, height: 12)
                        } else {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.clear)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
            }
        }
    }
    
    private func generateWeeks() -> [Int] {
        return Array(0..<52) // 52周
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