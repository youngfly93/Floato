//
//  SettingsView.swift
//  Floato
//
//  Created by 杨飞 on 2025/6/15.
//

import SwiftUI

struct SettingsView: View {
    @Environment(TodoStore.self) private var store
    @State private var title = ""
    @State private var pomos = 1
    @State private var selectedCategory: TodoStore.TaskCategory = .work
    
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
            Section {
                Button("显示悬浮窗") {
                    WindowManager.shared.showFloatingPanel(with: store)
                }
                .buttonStyle(.borderedProminent)
                
                Button("退出程序") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 260, height: 320)
    }
}