//
//  HomeStationsShelf.swift
//  Port Music
//

import SwiftUI

struct HomeStationsShelf: View {
    let stations = ["Port 1 Radio", "Chill Beats", "Deep Focus", "Workout Energy", "Trending Hits"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Radiosender & Stationen")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(stations, id: \.self) { station in
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.portSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.portBorder, lineWidth: 1)
                                    )
                                    .frame(width: 140, height: 140)

                                Image(systemName: "radio.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.portBrand)
                            }
                            Text(station)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .frame(width: 140, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
