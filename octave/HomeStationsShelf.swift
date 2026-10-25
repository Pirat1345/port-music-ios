//
//  HomeStationsShelf.swift
//  octave
//

import SwiftUI

struct HomeStationsShelf: View {
    let stations = ["Octave 1 Radio", "Chill Instrumental", "Hyperpop Club", "Deep Focus", "Workout Energy"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Live & Algorithmic Stations")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(stations, id: \.self) { station in
                        VStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 140, height: 140)

                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                            }
                            Text(station)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .frame(width: 140)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
