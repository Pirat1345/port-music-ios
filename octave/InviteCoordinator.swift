//
//  InviteCoordinator.swift
//  octave
//

import Foundation

final class InviteCoordinator {
    static let shared = InviteCoordinator()
    func createInviteLink(for id: String) -> URL {
        URL(string: "https://music.octavestreaming.com/party/\(id)")!
    }
}
