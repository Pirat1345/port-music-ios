//
//  RadioView.swift
//  octave
//

import SwiftUI

struct RadioView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Radio")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                RadioRecents()
            }
            .padding(.bottom, 100)
        }
    }
}
