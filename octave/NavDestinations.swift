//
//  NavDestinations.swift
//  octave
//

import SwiftUI

enum NavDestination: Hashable {
    case album(title: String, artist: String, artwork: String?)
    case artist(name: String)
    case playlist(title: String)
}
