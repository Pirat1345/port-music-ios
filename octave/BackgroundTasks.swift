//
//  BackgroundTasks.swift
//  octave
//

import BackgroundTasks

final class PortBackgroundTasks {
    static let refreshIdentifier = "com.portmusic.refresh"
    static let smartDownloadsIdentifier = "com.portmusic.smartdownloads"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshIdentifier, using: nil) { task in
            task.setTaskCompleted(success: true)
        }
    }
}

typealias OctaveBackgroundTasks = PortBackgroundTasks
