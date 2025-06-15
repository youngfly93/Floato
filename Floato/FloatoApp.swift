//
//  FloatoApp.swift
//  Floato
//
//  Created by 杨飞 on 2025/6/15.
//

import SwiftUI
import AppKit

// 全局的 WindowManager 来管理悬浮窗
class WindowManager: ObservableObject {
    static let shared = WindowManager()
    private var floatingPanel: FloatingPanel?
    
    func showFloatingPanel(with store: TodoStore) {
        if floatingPanel == nil {
            floatingPanel = FloatingPanel()
            let hostingView = NSHostingView(rootView: OverlayView().environment(store))
            floatingPanel?.contentView = hostingView
            
            // 设置窗口内容大小自动调整
            hostingView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            hostingView.setContentHuggingPriority(.defaultHigh, for: .vertical)
            floatingPanel?.isRestorable = false
        }
        floatingPanel?.orderFrontRegardless()
    }
    
    func hideFloatingPanel() {
        floatingPanel?.orderOut(nil)
    }
}

@main
struct FloatoApp: App {
    @State private var store = TodoStore()
    @State private var isPaused = false
    
    init() {
        requestNotificationPermission()
        setupAutoLaunch()
    }
    
    var body: some Scene {
        // 菜单栏入口
        MenuBarExtra {
            SettingsView()
                .environment(store)
                .onAppear {
                    // 启动时自动显示悬浮窗
                    WindowManager.shared.showFloatingPanel(with: store)
                }
        } label: {
            if let currentIndex = store.currentIndex,
               currentIndex < store.items.count,
               !store.items[currentIndex].isDone {
                // 显示倒计时
                HStack(spacing: 2) {
                    Image("StatusBarIcon")
                        .renderingMode(.template)
                    Text("\(store.items[currentIndex].finishedPomos)/\(store.items[currentIndex].targetPomos)")
                        .monospacedDigit()
                        .font(.system(size: 11, weight: .medium))
                }
            } else {
                Image("StatusBarIcon")
                    .renderingMode(.template)
            }
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandMenu("Pomodoro") {
                Button("显示悬浮窗") {
                    WindowManager.shared.showFloatingPanel(with: store)
                }
                .keyboardShortcut("f", modifiers: [.command])
                
                Button(action: togglePause) {
                    Text("Pause / Resume")
                }
                .keyboardShortcut(" ", modifiers: [.command])
            }
        }
    }
    
    private func togglePause() {
        isPaused.toggle()
    }
}
