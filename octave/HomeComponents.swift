//
//  HomeComponents.swift
//  Port Music
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = "Alle anzeigen"
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Spacer()
            if let actionTitle {
                Button(actionTitle) {
                    action?()
                }
                .font(.subheadline)
                .foregroundColor(.portBrand)
            }
        }
        .padding(.horizontal)
    }
}
