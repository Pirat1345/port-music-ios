//
//  PartyRoomView.swift
//  octave
//

import SwiftUI

struct PartyRoomView: View {
    @State private var client = PartyClient.shared

    var body: some View {
        VStack {
            Text("Port Music Party Room")
                .font(.title2)
                .fontWeight(.bold)
            Text("Listen together in real-time")
                .foregroundColor(.secondary)
        }
    }
}
