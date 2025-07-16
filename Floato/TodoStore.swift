//
//  TodoStore.swift
//  Floato
//
//  Created by 杨飞 on 2025/6/15.
//

import SwiftUI
import Observation

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
    
    init() { load() }
    
    func add(title: String, pomos: Int, category: TaskCategory = .work) {
        items.append(.init(title: title, targetPomos: pomos, category: category))
        save()
        if currentIndex == nil { currentIndex = 0 }
    }
    
    func markCurrentPomoDone() {
        guard let idx = currentIndex else { return }
        items[idx].finishedPomos += 1
        if items[idx].finishedPomos >= items[idx].targetPomos {
            items[idx].isDone = true
            advance()
        }
        save()
    }
    
    func advance() {
        guard let i = currentIndex else { return }
        
        // 查找下一个未完成的任务
        for nextIndex in (i + 1)..<items.count {
            if !items[nextIndex].isDone {
                currentIndex = nextIndex
                return
            }
        }
        
        // 如果没有找到后续的未完成任务，设置为nil
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