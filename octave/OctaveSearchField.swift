//
//  OctaveSearchField.swift
//  Port Music
//

import SwiftUI

struct PortSearchField: View {
    @Binding var text: String
    var onCommit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.portBrand)
            TextField("Künstler, Titel, Alben suchen...", text: $text)
                .foregroundColor(.white)
                .onSubmit(onCommit)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.portTextMuted)
                }
            }
        }
        .padding(12)
        .background(Color.portSurfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.portBorder, lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

typealias OctaveSearchField = PortSearchField
