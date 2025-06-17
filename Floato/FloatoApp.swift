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
        print("showFloatingPanel called")
        
        // 如果窗口已存在且可见，则不做任何操作
        if let panel = floatingPanel, panel.isVisible {
            print("Panel already visible, bringing to front")
            panel.makeKeyAndOrderFront(nil)
            return
        }
        
        print("Creating new floating panel")
        
        // 如果窗口不存在或已关闭，创建新窗口
        floatingPanel = FloatingPanel()
        
        // 设置关闭回调，清理引用
        floatingPanel?.onClose = { [weak self] in
            print("Floating panel closed")
            self?.floatingPanel = nil
        }
        
        // 创建 SwiftUI 内容视图
        let hostingView = NSHostingView(rootView: 
            OverlayView()
                .environment(store)
                .background(.clear)  // 确保背景透明
        )
        
        // 设置窗口内容大小自动调整
        hostingView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        hostingView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        
        // 将 SwiftUI 视图添加到毛玻璃视图中
        if let visualEffectView = floatingPanel?.contentView as? NSVisualEffectView {
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            visualEffectView.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
            ])
        }
        
        floatingPanel?.isRestorable = false
        floatingPanel?.makeKeyAndOrderFront(nil)
        floatingPanel?.orderFrontRegardless()
        
        print("Floating panel should be visible now")
    }
    
    func hideFloatingPanel() {
        floatingPanel?.orderOut(nil)
    }
}

@main
struct FloatoApp: App {
    @State private var store = TodoStore()
    @State private var isPaused = false
    @State private var hasLaunched = false
    
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
                    if !hasLaunched {
                        hasLaunched = true
                        // 延迟显示悬浮窗，等待应用完全启动
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            WindowManager.shared.showFloatingPanel(with: store)
                        }
                    }
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
