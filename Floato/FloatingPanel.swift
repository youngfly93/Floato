//
//  FloatingPanel.swift
//  Floato
//
//  Created by 杨飞 on 2025/6/15.
//

import SwiftUI
import AppKit
import QuartzCore

// 自定义 NSPanel 来实现真正的全屏覆盖和毛玻璃效果
final class FloatingPanel: NSPanel {
    private var visualEffectView: NSVisualEffectView!
    
    init() {
        let style: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .fullSizeContentView]
        super.init(contentRect: NSRect(x: 100, y: 100, width: 240, height: 300),
                   styleMask: style,
                   backing: .buffered,
                   defer: false)
        
        setupBlurEffect()
        setupWindowProperties()
        setupVisualEffect()
        
        // 监听窗口大小变化以重新应用形状
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification,
            object: self
        )
        
        orderFrontRegardless()
    }
    
    private func setupBlurEffect() {
        // 关键：设置窗口透明以支持毛玻璃效果
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false  // 我们会在视图层添加阴影
        
        // 设置标题栏透明
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
    }
    
    private func setupWindowProperties() {
        isReleasedWhenClosed = false
        level = .mainMenu
        ignoresMouseEvents = false
        isMovableByWindowBackground = true
        
        // 关键：加入所有 Spaces 并允许附着全屏窗
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // 设置窗口大小自动调整
        setContentSize(NSSize(width: 240, height: 300))
        minSize = NSSize(width: 60, height: 60)
        maxSize = NSSize(width: 400, height: 600)
    }
    
    private func setupVisualEffect() {
        // 创建毛玻璃视图作为窗口的根内容视图
        visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        
        // 设置为窗口的内容视图
        contentView = visualEffectView
        
        // 关键：创建自定义窗口形状来实现真正的圆角
        updateWindowShape(with: 16)
    }
    
    // 创建自定义窗口形状
    private func updateWindowShape(with cornerRadius: CGFloat) {
        let windowFrame = frame
        let path = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: windowFrame.width, height: windowFrame.height), 
                               xRadius: cornerRadius, yRadius: cornerRadius)
        
        // 创建 CAShapeLayer 作为窗口遮罩
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        
        // 将路径应用到窗口的图层
        if let windowLayer = contentView?.layer {
            windowLayer.mask = shapeLayer
        }
    }
    
    // 更新圆角半径的方法
    func updateCornerRadius(_ radius: CGFloat) {
        updateWindowShape(with: radius)
    }
    
    // 窗口大小变化时重新应用形状
    @objc private func windowDidResize() {
        // 使用当前设置的圆角半径重新创建形状
        let currentRadius: CGFloat = frame.width < 100 ? 18 : 16
        updateWindowShape(with: currentRadius)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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