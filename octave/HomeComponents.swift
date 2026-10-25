//
//  HomeComponents.swift
//  octave
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = "See All"
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
            Spacer()
            if let actionTitle {
                Button(actionTitle) {
                    action?()
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
        }
        .padding(.horizontal)
    }
}
