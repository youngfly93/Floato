//
//  TodoStore.swift
//  Floato
//
//  Created by 杨飞 on 2025/6/15.
//

import SwiftUI
import Observation

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
            case .work: return .green
            case .study: return .red
            case .personal: return .blue
            case .health: return .orange
            case .hobby: return .purple
            }
        }
        
        var iconName: String {
            switch self {
            case .work: return "briefcase.fill"
            case .study: return "book.fill"
            case .personal: return "person.fill"
            case .health: return "heart.fill"
            case .hobby: return "star.fill"
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
        if let i = currentIndex, i + 1 < items.count {
            currentIndex = i + 1
        } else {
            currentIndex = nil
        }
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