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
    @FocusState private var isTitleFocused: Bool
    @AppStorage("pomodoroMinutes") private var pomodoroMinutes = 25
    @AppStorage("selectedSound") private var selectedSound = "glass"
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    var body: some View {
        Form {
            Section("新任务") {
                TextField("标题", text: $title)
                    .focused($isTitleFocused)
                
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
                    isTitleFocused = true
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
        .onAppear {
            // Auto-focus on title field when settings view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTitleFocused = true
            }
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

