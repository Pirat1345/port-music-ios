//
//  PartyClient.swift
//  octave
//

import Foundation
import Observation

@Observable
final class PartyClient {
    static let shared = PartyClient()
    var roomCode: String?
    var participants: [String] = []
    var isHost: Bool = false
}
