//
//  BackgroundTasks.swift
//  octave
//

import BackgroundTasks

final class OctaveBackgroundTasks {
    static let refreshIdentifier = "com.octave.refresh"
    static let smartDownloadsIdentifier = "com.octave.smartdownloads"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshIdentifier, using: nil) { task in
            task.setTaskCompleted(success: true)
        }
    }
}
