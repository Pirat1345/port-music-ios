//
//  Toaster.swift
//  octave
//

import SwiftUI
import Observation

@Observable
final class Toaster {
    static let shared = Toaster()
    var currentMessage: String?

    func show(message: String) {
        currentMessage = message
    }
}
