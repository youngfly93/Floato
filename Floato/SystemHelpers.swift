//
//  SystemHelpers.swift
//  Floato
//
//  Created by 杨飞 on 2025/6/15.
//

import UserNotifications
import AVFoundation
import ServiceManagement
import AppKit

enum SoundType: String, CaseIterable {
    case none = "无声音"
    case beep = "系统提示音"
    case glass = "玻璃音"
    case blow = "吹气音"
    case bottle = "瓶子音"
    case frog = "青蛙音"
    case funk = "Funk"
    case sosumi = "Sosumi"
    case submarine = "潜水艇音"
    case tink = "叮音"
    
    var soundName: String? {
        switch self {
        case .none: return nil
        case .beep: return nil  // 使用 NSSound.beep()
        case .glass: return "Glass"
        case .blow: return "Blow"
        case .bottle: return "Bottle"
        case .frog: return "Frog"
        case .funk: return "Funk"
        case .sosumi: return "Sosumi"
        case .submarine: return "Submarine"
        case .tink: return "Tink"
        }
    }
}

func notifyDone(title: String, soundEnabled: Bool = true, hapticEnabled: Bool = true) {
    let center = UNUserNotificationCenter.current()
    let content = UNMutableNotificationContent()
    content.title = "番茄完成 🎉"
    content.body = title
    content.sound = soundEnabled ? .default : nil  // 通知声音
    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil)
    Task { try? await center.add(request) }
    
    // 播放额外的系统声音
    if soundEnabled {
        let soundType = SoundType(rawValue: UserDefaults.standard.string(forKey: "selectedSound") ?? "glass") ?? .glass
        
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
    
    // 触发触控板震动反馈（如果设备支持）
    if hapticEnabled {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}

func requestNotificationPermission() {
    Task {
        let center = UNUserNotificationCenter.current()
        try? await center.requestAuthorization(options: [.alert, .sound])
    }
}

func setupAutoLaunch() {
    _ = try? SMAppService.mainApp.register()
}