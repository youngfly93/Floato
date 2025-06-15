//
//  SystemHelpers.swift
//  Floato
//
//  Created by 杨飞 on 2025/6/15.
//

import UserNotifications
import AVFoundation
import ServiceManagement

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
    
    AudioServicesPlaySystemSound(1005)
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