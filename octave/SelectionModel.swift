//
//  SelectionModel.swift
//  octave
//

import Foundation
import Observation

@Observable
final class SelectionModel: @unchecked Sendable {
    var selectedIds: Set<String> = []
}
