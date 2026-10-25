//
//  LibraryPinsStore.swift
//  octave
//

import Foundation
import Observation

@Observable
final class LibraryPinsStore {
    static let shared = LibraryPinsStore()
    var pinnedIds: [String] = []
}
