//
//  FloatingPanel.swift
//  Floato
//
//  Created by 杨飞 on 2025/6/15.
//

import SwiftUI
import AppKit

// 自定义 NSPanel 来实现真正的全屏覆盖
final class FloatingPanel: NSPanel {
    
    init() {
        let style: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        super.init(contentRect: NSRect(x: 100, y: 100, width: 240, height: 300),
                   styleMask: style,
                   backing: .buffered,
                   defer: false)
        
        isReleasedWhenClosed = false
        level = .mainMenu  // 或者 .screenSaver
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = false
        isMovableByWindowBackground = true
        
        // 关键：加入所有 Spaces 并允许附着全屏窗
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // 设置窗口大小自动调整
        setContentSize(NSSize(width: 240, height: 300))
        minSize = NSSize(width: 60, height: 60)
        maxSize = NSSize(width: 400, height: 600)
        
        orderFrontRegardless()
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// SwiftUI 包装器
struct FloatingPanelWrapper: NSViewControllerRepresentable {
    @Environment(TodoStore.self) private var store
    
    func makeNSViewController(context: Context) -> NSViewController {
        let viewController = NSViewController()
        let hostingView = NSHostingView(rootView: OverlayView().environment(store))
        viewController.view = hostingView
        return viewController
    }
    
    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {
        // 更新视图
    }
    
    static func showFloatingPanel(store: TodoStore) -> FloatingPanel {
        let panel = FloatingPanel()
        let hostingView = NSHostingView(rootView: OverlayView().environment(store))
        panel.contentView = hostingView
        panel.orderFrontRegardless()
        return panel
    }
}