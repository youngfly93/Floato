//
//  OverlayView.swift
//  Floato
//
//  Created by 杨飞 on 2025/6/15.
//

import SwiftUI

struct OverlayView: View {
    @Environment(TodoStore.self) private var store
    @State private var secondsLeft = 0
    @State private var phase: PomodoroClock.Phase = .idle
    @State private var isCollapsed = false
    private let clock = PomodoroClock()
    
    var body: some View {
        Group {
            if isCollapsed {
                collapsedView
            } else {
                expandedView
            }
        }
        .task(id: store.currentIndex) {
            guard store.currentIndex != nil else { return }
            for await phase in await clock.start() {
                self.phase = phase
                if case .running(let s) = phase { secondsLeft = s }
                if case .breakTime = phase {
                    await MainActor.run {
                        if let idx = store.currentIndex {
                            notifyDone(title: store.items[idx].title)
                        }
                        store.markCurrentPomoDone()
                    }
                    await clock.stop()
                }
            }
        }
    }
    
    // 折叠状态 - 小方块只显示时间
    private var collapsedView: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.3)) { isCollapsed = false } }) {
            VStack(spacing: 4) {
                if case .running = phase {
                    Text(timeString(secondsLeft))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                } else {
                    Image(systemName: {
                        switch phase {
                        case .breakTime:
                            return "cup.and.saucer.fill"
                        default:
                            return "timer"
                        }
                    }())
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 60, height: 60)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 4, x: 0, y: 2)
    }
    
    // 展开状态 - 完整悬浮窗
    private var expandedView: some View {
        VStack(spacing: 12) {
            // 头部区域，包含折叠按钮
            HStack {
                Spacer()
                Button(action: { withAnimation(.easeInOut(duration: 0.3)) { isCollapsed = true } }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            header
            Divider()
            taskList
        }
        .padding(16)
        .frame(minWidth: 220, maxWidth: .infinity,
               minHeight: 260, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8, x: 0, y: 4)
    }
    
    private var header: some View {
        switch phase {
        case .running:
            return AnyView(
                VStack {
                    ProgressView(value: Double(secondsLeft),
                                 total: 25*60)
                        .progressViewStyle(.circular)
                    Text(timeString(secondsLeft))
                        .font(.title2).monospacedDigit()
                }
            )
        case .breakTime:
            return AnyView(Text("Break ☕️").font(.title2))
        default:
            return AnyView(Text("Ready 🍅").font(.title2))
        }
    }
    
    private var taskList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(store.items) { item in
                    HStack {
                        Image(systemName: item.isDone
                              ? "checkmark.circle.fill" : "circle")
                        Text(item.title)
                            .strikethrough(item.isDone)
                        Spacer()
                        Text("\(item.finishedPomos)/\(item.targetPomos)")
                            .font(.caption2).monospacedDigit()
                    }
                }
            }
        }
        .frame(maxHeight: 150)
    }
    
    private func timeString(_ secs: Int) -> String {
        "\(secs / 60):" + String(format: "%02d", secs % 60)
    }
}