//
//  RadioView.swift
//  Port Music
//

import SwiftUI

struct RadioView: View {
    var body: some View {
        ZStack {
            Color.portBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Radio")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.top, 16)

                    RadioRecents()
                }
                .padding(.bottom, 120)
            }
        }
        .navigationBarHidden(true)
    }
}
