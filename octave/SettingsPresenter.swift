//
//  SettingsPresenter.swift
//  octave
//

import Foundation
import Observation

@Observable
final class SettingsPresenter: @unchecked Sendable {
    var streamingQuality: String = "320"
    var allowCellularDownloads: Bool = false
}
