import Foundation
import Observation

@Observable
final class StatsManager {
    static let shared = StatsManager()
    
    // Key used for UserDefaults storage
    private let storageKey = "dailyPomodoroCounts"
    
    // 使用日期（00:00 开始）作为键，对应当天完成的番茄钟数量
    var dailyCounts: [Date: Int] = [:]
    
    private init() {
        load()
    }
    
    /// 在当前日期 +1
    func increment() {
        let today = Calendar.current.startOfDay(for: Date())
        dailyCounts[today, default: 0] += 1
        save()
    }
    
    // MARK: - Persistence
    
    private func save() {
        let formatter = ISO8601DateFormatter()
        let dict = dailyCounts.reduce(into: [String: Int]()) { result, pair in
            result[formatter.string(from: pair.key)] = pair.value
        }
        UserDefaults.standard.set(dict, forKey: storageKey)
    }
    
    private func load() {
        guard let dict = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Int] else { return }
        let formatter = ISO8601DateFormatter()
        for (key, value) in dict {
            if let date = formatter.date(from: key) {
                let day = Calendar.current.startOfDay(for: date)
                dailyCounts[day] = value
            }
        }
    }
} 