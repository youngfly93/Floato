import Foundation
import SwiftUI

@Observable
class StatisticsStore {
    private let statsKey = "pomodoro_statistics"
    private var statistics: [String: Int] = [:]
    
    init() {
        loadStatistics()
    }
    
    // 记录今天完成的番茄钟
    func recordPomodoro(for date: Date = Date()) {
        let key = dateKey(for: date)
        statistics[key, default: 0] += 1
        saveStatistics()
    }
    
    // 获取指定日期的番茄钟完成数量
    func getPomodoroCount(for date: Date) -> Int {
        let key = dateKey(for: date)
        return statistics[key, default: 0]
    }
    
    // 获取最近365天的统计数据，用于热力图
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
    
    // 获取统计摘要
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
}