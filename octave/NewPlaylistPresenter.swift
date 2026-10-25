//
//  NewPlaylistPresenter.swift
//  octave
//

import Foundation
import Observation

@Observable
final class NewPlaylistPresenter: @unchecked Sendable {
    var name: String = ""
    var isPrivate: Bool = false
}
