//
//  LibraryPinsStore.swift
//  octave
//

import Foundation
import Observation

@Observable
final class LibraryPinsStore: @unchecked Sendable {
    static let shared = LibraryPinsStore()
    var pinnedIds: [String] = []
}
