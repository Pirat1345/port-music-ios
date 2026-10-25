//
//  SettingsPresenter.swift
//  octave
//

import Foundation
import Observation

@Observable
final class SettingsPresenter {
    var streamingQuality: String = "320"
    var allowCellularDownloads: Bool = false
}
