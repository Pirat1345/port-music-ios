//
//  SelectionModel.swift
//  octave
//

import Foundation
import Observation

@Observable
final class SelectionModel {
    var selectedIds: Set<String> = []
}
