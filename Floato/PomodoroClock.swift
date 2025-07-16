//
//  PomodoroClock.swift
//  Floato
//
//  Created by 杨飞 on 2025/6/15.
//

import Foundation

actor PomodoroClock {
    enum Phase {
        case running(Int)
        case breakTime(Int)
        case idle
    }
    
    private var workSeconds: Int
    let breakSeconds = 5 * 60
    private var task: Task<Void, Never>?
    
    init(workMinutes: Int = 25) {
        self.workSeconds = workMinutes * 60
    }
    
    func updateWorkDuration(minutes: Int) {
        self.workSeconds = minutes * 60
    }
    
    func start(skipBreak: Bool = false) -> AsyncStream<Phase> {
        AsyncStream { cont in
            task?.cancel()
            task = Task {
                // 工作时间倒计时
                var remaining = workSeconds
                while remaining > 0 {
                    cont.yield(.running(remaining))
                    try? await Task.sleep(for: .seconds(1))
                    remaining -= 1
                }
                
                // 确保发送 0 秒状态
                print("🔚 Work phase ending, sending final 0 state")
                cont.yield(.running(0))
                
                // 只有在不是最后一个任务时才添加休息时间
                if !skipBreak {
                    var breakRemaining = breakSeconds
                    while breakRemaining > 0 {
                        cont.yield(.breakTime(breakRemaining))
                        try? await Task.sleep(for: .seconds(1))
                        breakRemaining -= 1
                    }
                }
                
                cont.finish()
            }
        }
    }
    
    func stop() {
        task?.cancel()
    }
}