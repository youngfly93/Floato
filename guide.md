1 — 搭好悬浮窗场景
关键思想：用 WindowGroup 建一个独立窗口，再用 windowLevel(.floating) 让它永远置顶。macOS 15 以后 SwiftUI 已原生支持，无需 AppKit hack。
developer.apple.com

在 PomodoroOverlayApp.swift 里修改主场景：

swift
复制
编辑
@main
struct PomodoroOverlayApp: App {
    @State private var store = TodoStore()   // 全局状态

    var body: some Scene {
        // ① 菜单栏入口（点击后弹设置窗）
        MenuBarExtra {
            SettingsView()
                .environment(store)
        } label: {
            Label("Pomodoro", systemImage: "timer")
        }
        .menuBarExtraStyle(.window)          // 保留默认下拉菜单样式  :contentReference[oaicite:1]{index=1}

        // ② 悬浮窗
        WindowGroup(id: "overlay") {
            OverlayView()
                .environment(store)
        }
        .defaultSize(width: 240, height: 300)
        .windowLevel(.floating)               // 永远顶置  :contentReference[oaicite:2]{index=2}
        .windowStyle(.plain)                  // 去掉标题栏
        .windowIsMovableByWindowBackground()
        .windowCollectionBehavior(.canJoinAllSpaces) // 跨 Spaces 可见 :contentReference[oaicite:3]{index=3}
    }
}
编译 ➜ 运行 (⌘R)

右上角菜单栏出现番茄图标；

点击图标会弹个空白 SettingsView；

在 Xcode ▸ Debug ▸ Open Overlay Scene “overlay” 就能看到置顶透明窗口。

2 — 数据模型（Todo + 应用状态）
新增文件 TodoStore.swift：

swift
复制
编辑
import SwiftUI

@Observable                         // Swift 6 新宏：自动发 `objectWillChange`
final class TodoStore {
    struct Item: Identifiable, Codable, Hashable {
        var id = UUID()
        var title: String
        var targetPomos: Int
        var finishedPomos: Int = 0
        var isDone: Bool = false
    }

    @AppStorage("todos") private var data = Data()  // 本地 JSON 持久化
    @Published var items: [Item] = []
    @Published var currentIndex: Int? = nil         // 正在倒计时的任务

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
            currentIndex = nil    // All done
        }
    }

    private func save() {
        data = try! JSONEncoder().encode(items)
    }
    private func load() {
        items = (try? JSONDecoder().decode([Item].self, from: data)) ?? []
        currentIndex = items.firstIndex(where: { !$0.isDone })
    }
}
3 — 计时引擎（不阻塞 UI）
采用 AsyncStream + Task.sleep(for:)，更精准且完全非阻塞。
forums.swift.org

新增文件 PomodoroClock.swift：

swift
复制
编辑
import Foundation

actor PomodoroClock {
    enum Phase {
        case running(Int)   // 剩余秒数
        case breakTime(Int)
        case idle
    }

    let workSeconds = 25 * 60
    let breakSeconds = 5 * 60
    private var task: Task<Void, Never>?

    func start() -> AsyncStream<Phase> {
        AsyncStream { cont in
            task?.cancel()
            task = Task {
                var remaining = workSeconds
                // 工作阶段
                while remaining > 0 {
                    cont.yield(.running(remaining))
                    try await Task.sleep(for: .seconds(1))
                    remaining -= 1
                }
                // 休息阶段
                cont.yield(.breakTime(breakSeconds))
                cont.finish()                // MVP 里休息不计时，直接结束
            }
        }
    }

    func stop() { task?.cancel() }
}
4 — OverlayView：倒计时悬浮窗 UI
新建文件 OverlayView.swift：

swift
复制
编辑
import SwiftUI

struct OverlayView: View {
    @Environment(TodoStore.self) private var store
    @State private var secondsLeft = 0
    @State private var phase: PomodoroClock.Phase = .idle
    private let clock = PomodoroClock()

    var body: some View {
        VStack(spacing: 12) {
            header
            Divider()
            taskList
        }
        .padding(16)
        .frame(minWidth: 220, maxWidth: .infinity,
               minHeight: 260, maxHeight: .infinity)
        .background(.ultraThinMaterial)       // 原生毛玻璃
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: store.currentIndex) {       // 任务切换重新开流
            guard store.currentIndex != nil else { return }
            for await phase in clock.start() {
                self.phase = phase
                if case .running(let s) = phase { secondsLeft = s }
                if case .breakTime = phase {
                    await store.markCurrentPomoDone()  // 更新状态
                    await clock.stop()                 // 停止旧流
                }
            }
        }
    }

    private var header: some View {
        switch phase {
        case .running:
            return AnyView(
                VStack {
                    ProgressView(value: Double(secondsLeft),
                                 total: 25*60)         // 粗暴 MVP 做法
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
运行观察：

加任务前计时器处于 “Ready”。

等下一步 SettingsView 能创建任务后，计时会自动开始。

5 — SettingsView：添加 / 删除任务
新建文件 SettingsView.swift：

swift
复制
编辑
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
                    title = ""; pomos = 1
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
        }
        .formStyle(.grouped)
        .frame(width: 260, height: 320)
    }
}
测试：

打开菜单栏番茄 ▸ “新任务”，输入标题＋番茄数点 添加；

悬浮窗立即刷新，计时自动开始；

每 25 分钟结束后调用 store.markCurrentPomoDone() ➜ UI 勾掉已完成任务、自动切换到下一个。

6 — 系统级完善
6 .1 完成提醒（通知 + 系统声音）
swift
复制
编辑
import UserNotifications
import AVFoundation   // 播放系统提示音

func notifyDone(title: String) {
    let center = UNUserNotificationCenter.current()
    let content = UNMutableNotificationContent()
    content.title = "番茄完成 🎉"
    content.body = title
    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil)
    Task { try? await center.add(request) }

    AudioServicesPlaySystemSound(1005)   // “ding” 声
}
在 OverlayView 里的 markCurrentPomoDone() 调用处加 notifyDone(title:)。

6 .2 菜单栏状态图标
swift
复制
编辑
MenuBarExtra {
    SettingsView().environment(store)
} label: {
    switch phase {
    case .running: Image(systemName: "timer")
    case .breakTime: Image(systemName: "cup.and.saucer")
    default: Image(systemName: "checkmark")
    }
}
6 .3 快捷键一键暂停 / 继续
swift
复制
编辑
Commands {
    CommandMenu("Pomodoro") {
        Button(action: togglePause) {
            Text("Pause / Resume")
        }
        .keyboardShortcut(" ", modifiers: [.command])
    }
}
6 .4 开机自启
swift
复制
编辑
import ServiceManagement

try? SMAppService.mainApp.register()     // 一行代码搞定  :contentReference[oaicite:5]{index=5}
将这行放到 PomodoroOverlayApp 的 init() 或 applicationDidFinishLaunching(_:) 中即可；Xcode 首次运行会弹系统对话框让用户确认。苹果文档详解见 SMAppService > mainApp。
developer.apple.com

7 — 打包、公证、分发
Archive

Product ▸ Archive

Organizer 窗口自动打开。

Developer ID 签名 & Notarize

在 Archive 条目上点 Distribute App

选 “Developer ID” ➜ “Build Product” ➜ 勾 “Upload”

等公证完成（状态栏会显示 ✓）。

导出 .dmg

Organizer 里点 “Distribute” ▸ “Copy App”

选择 “Disk Image” ➜ 生成 PomodoroOverlay.dmg

发给用户

上传到 GitHub Release / 网盘；或继续走「App Store Connect」流程提交到 Mac App Store。