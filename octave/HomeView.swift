//
//  HomeView.swift
//  octave
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Environment(AudioPlayer.self) private var player

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Top Header / Profile
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Good afternoon")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Listen to your favorite mixes & new releases")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    NavigationLink(destination: AccountSettingsView()) {
                        Image(systemName: "person.crop.circle")
                            .font(.title)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)

                // Continue Listening Chip
                HomeContinueChip()
                    .padding(.horizontal)

                // Featured Shelves
                HomeStationsShelf()

                ForYouShelves()

                NewShelves()
            }
            .padding(.bottom, 100)
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadHomeData()
        }
    }
}
