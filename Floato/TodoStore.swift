//
//  TodoStore.swift
//  Floato
//
//  Created by 杨飞 on 2025/6/15.
//

import SwiftUI
import Observation
import Foundation

// Statistics Store for tracking pomodoro completion
@Observable
class StatisticsStore {
    private let statsKey = "pomodoro_statistics"
    private let hourlyStatsKey = "pomodoro_hourly_statistics"
    private let categoryStatsKey = "pomodoro_category_statistics"
    private var statistics: [String: Int] = [:]
    private var hourlyStatistics: [String: Int] = [:]
    private var categoryStatistics: [String: Int] = [:]
    
    init() {
        loadStatistics()
        loadHourlyStatistics()
        loadCategoryStatistics()
    }
    
    // Record today's completed pomodoro
    func recordPomodoro(for date: Date = Date(), category: TodoStore.TaskCategory = .work) {
        let key = dateKey(for: date)
        let halfHourKey = halfHourlyKey(for: date)
        let categoryKey = categoryKey(for: date, category: category)
        
        statistics[key, default: 0] += 1
        hourlyStatistics[halfHourKey, default: 0] += 1
        categoryStatistics[categoryKey, default: 0] += 1
        
        saveStatistics()
        saveHourlyStatistics()
        saveCategoryStatistics()
    }
    
    // Get pomodoro count for specific date
    func getPomodoroCount(for date: Date) -> Int {
        let key = dateKey(for: date)
        return statistics[key, default: 0]
    }
    
    // Get heatmap data for last 365 days
    func getHeatmapData() -> [Date: Int] {
        var data: [Date: Int] = [:]
        let calendar = Calendar.current
        
        for dayOffset in 0..<365 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let key = dateKey(for: date)
            data[date] = statistics[key, default: 0]
        }
        
        return data
    }
    
    // Get today's half-hourly data (48 periods)
    func getTodayHalfHourlyData() -> [Int: Int] {
        var data: [Int: Int] = [:]
        let calendar = Calendar.current
        let today = Date()
        
        for period in 0..<48 {
            let hour = period / 2
            let minute = (period % 2) * 30
            guard let periodDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) else { continue }
            let key = halfHourlyKey(for: periodDate)
            data[period] = hourlyStatistics[key, default: 0]
        }
        
        return data
    }
    
    // Get today's category distribution data
    func getTodayCategoryData() -> [TodoStore.TaskCategory: Int] {
        var data: [TodoStore.TaskCategory: Int] = [:]
        let today = Date()
        
        for category in TodoStore.TaskCategory.allCases {
            let key = categoryKey(for: today, category: category)
            data[category] = categoryStatistics[key, default: 0]
        }
        
        return data
    }
    
    // Get statistics summary
    func getStatisticsSummary() -> (today: Int, thisWeek: Int, thisMonth: Int, total: Int) {
        let calendar = Calendar.current
        let now = Date()
        
        let today = getPomodoroCount(for: now)
        
        let thisWeek = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: now)
        }.reduce(0) { sum, date in
            sum + getPomodoroCount(for: date)
        }
        
        let thisMonth = (0..<30).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: now)
        }.reduce(0) { sum, date in
            sum + getPomodoroCount(for: date)
        }
        
        let total = statistics.values.reduce(0, +)
        
        return (today: today, thisWeek: thisWeek, thisMonth: thisMonth, total: total)
    }
    
    // MARK: - Private Methods
    
    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func hourlyKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH"
        return formatter.string(from: date)
    }
    
    private func halfHourlyKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH"
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let period = minute < 30 ? 0 : 1
        
        let baseHour = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        let hourString = formatter.string(from: baseHour)
        return "\(hourString)-\(period)"
    }
    
    private func categoryKey(for date: Date, category: TodoStore.TaskCategory) -> String {
        let dateString = dateKey(for: date)
        return "\(dateString)-\(category.rawValue)"
    }
    
    private func saveStatistics() {
        if let encoded = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(encoded, forKey: statsKey)
        }
    }
    
    private func loadStatistics() {
        guard let data = UserDefaults.standard.data(forKey: statsKey),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            statistics = [:]
            return
        }
        statistics = decoded
    }
    
    private func saveHourlyStatistics() {
        if let encoded = try? JSONEncoder().encode(hourlyStatistics) {
            UserDefaults.standard.set(encoded, forKey: hourlyStatsKey)
        }
    }
    
    private func loadHourlyStatistics() {
        guard let data = UserDefaults.standard.data(forKey: hourlyStatsKey),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            hourlyStatistics = [:]
            return
        }
        hourlyStatistics = decoded
    }
    
    private func saveCategoryStatistics() {
        if let encoded = try? JSONEncoder().encode(categoryStatistics) {
            UserDefaults.standard.set(encoded, forKey: categoryStatsKey)
        }
    }
    
    private func loadCategoryStatistics() {
        guard let data = UserDefaults.standard.data(forKey: categoryStatsKey),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            categoryStatistics = [:]
            return
        }
        categoryStatistics = decoded
    }
}

// Color extension to support hex values
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

@Observable
final class TodoStore {
    enum TaskCategory: String, CaseIterable, Codable {
        case work = "工作"
        case study = "学习"
        case personal = "个人"
        case health = "健康"
        case hobby = "兴趣"
        
        var color: Color {
            switch self {
            case .work: return Color(hex: "00b1b0")      // 青绿色
            case .study: return Color(hex: "fec84d")     // 金黄色
            case .personal: return Color(hex: "ff8370")   // 珊瑚橙
            case .health: return Color(hex: "2a9d8f")     // 深绿色
            case .hobby: return Color(hex: "e42256")      // 玫红色
            }
        }
        
        var iconName: String {
            switch self {
            case .work: return "inset.filled.rectangle.and.person.filled"
            case .study: return "books.vertical.fill"
            case .personal: return "figure.wave"
            case .health: return "stethoscope.circle"
            case .hobby: return "figure.basketball"
            }
        }
    }
    
    struct Item: Identifiable, Codable, Hashable {
        var id = UUID()
        var title: String
        var targetPomos: Int
        var finishedPomos: Int = 0
        var isDone: Bool = false
        var category: TaskCategory = .work
    }
    
    var items: [Item] = []
    var currentIndex: Int? = nil
    var statisticsStore = StatisticsStore()
    
    init() { load() }
    
    func add(title: String, pomos: Int, category: TaskCategory = .work) {
        items.append(.init(title: title, targetPomos: pomos, category: category))
        save()
        if currentIndex == nil { currentIndex = 0 }
    }
    
    func markCurrentPomoDone() {
        guard let idx = currentIndex else { return }
        print("📝 Marking pomo done for task \(idx): \(items[idx].finishedPomos) -> \(items[idx].finishedPomos + 1)")
        items[idx].finishedPomos += 1
        
        // 记录番茄钟完成统计，传入当前任务的类型
        statisticsStore.recordPomodoro(category: items[idx].category)
        
        if items[idx].finishedPomos >= items[idx].targetPomos {
            print("✅ Task \(idx) completed: \(items[idx].finishedPomos)/\(items[idx].targetPomos)")
            items[idx].isDone = true
            advance()
        } else {
            print("🔄 Task \(idx) still in progress: \(items[idx].finishedPomos)/\(items[idx].targetPomos)")
        }
        save()
    }
    
    func advance() {
        guard let i = currentIndex else { return }
        
        // 查找下一个未完成的任务
        for nextIndex in (i + 1)..<items.count {
            if !items[nextIndex].isDone {
                print("🔄 Advancing from task \(i) to task \(nextIndex)")
                currentIndex = nextIndex
                return
            }
        }
        
        // 如果没有找到后续的未完成任务，设置为nil
        print("✅ All tasks completed, setting currentIndex to nil")
        currentIndex = nil
    }
    
    func isLastTask() -> Bool {
        guard let idx = currentIndex else { return true }
        // 检查是否还有其他未完成的任务（不仅仅是后续的）
        for i in 0..<items.count {
            if i == idx { continue } // 跳过当前任务
            if !items[i].isDone {
                return false  // 还有其他未完成的任务
            }
        }
        return true  // 所有其他任务都已完成
    }
    
    func resetAll() {
        items.removeAll()
        currentIndex = nil
        save()
        UserDefaults.standard.synchronize()
    }
    
    func save() {
        let data = try! JSONEncoder().encode(items)
        UserDefaults.standard.set(data, forKey: "todos")
    }
    
    private func load() {
        let data = UserDefaults.standard.data(forKey: "todos") ?? Data()
        items = (try? JSONDecoder().decode([Item].self, from: data)) ?? []
        currentIndex = items.firstIndex(where: { !$0.isDone })
    }
}