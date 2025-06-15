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
    struct Item: Identifiable, Codable, Hashable {
        var id = UUID()
        var title: String
        var targetPomos: Int
        var finishedPomos: Int = 0
        var isDone: Bool = false
    }
    
    var items: [Item] = []
    var currentIndex: Int? = nil
    
    init() { load() }
    
    func add(title: String, pomos: Int) {
        items.append(.init(title: title, targetPomos: pomos))
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