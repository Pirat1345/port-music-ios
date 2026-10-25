//
//  OctaveTopBar.swift
//  Port Music
//

import SwiftUI

struct PortTopBar: View {
    var body: some View {
        HStack(spacing: 8) {
            Image("PortLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text("Port Music")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

typealias OctaveTopBar = PortTopBar
