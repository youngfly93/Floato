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
    
    var body: some View {
        Form {
            Section("新任务") {
                TextField("标题", text: $title)
                Stepper(value: $pomos, in: 1...8) {
                    Text("番茄数: \(pomos)")
                }
                Button("添加") {
                    guard !title.isEmpty else { return }
                    store.add(title: title, pomos: pomos)
                    title = ""
                    pomos = 1
                }
                .disabled(title.isEmpty)
            }
            Section("列表") {
                ForEach(store.items) { item in
                    Text(item.title)
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
            }
        }
        .formStyle(.grouped)
        .frame(width: 260, height: 320)
    }
}