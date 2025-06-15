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
    
    let workSeconds = 25 * 60
    let breakSeconds = 5 * 60
    private var task: Task<Void, Never>?
    
    func start() -> AsyncStream<Phase> {
        AsyncStream { cont in
            task?.cancel()
            task = Task {
                var remaining = workSeconds
                while remaining > 0 {
                    cont.yield(.running(remaining))
                    try? await Task.sleep(for: .seconds(1))
                    remaining -= 1
                }
                cont.yield(.breakTime(breakSeconds))
                cont.finish()
            }
        }
    }
    
    func stop() {
        task?.cancel()
    }
}