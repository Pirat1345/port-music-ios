//
//  HomeView.swift
//  Port Music
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Environment(AudioPlayer.self) private var player

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Guten Morgen"
        } else if hour < 18 {
            return "Guten Tag"
        } else {
            return "Guten Abend"
        }
    }

    var body: some View {
        ZStack {
            Color.portBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Top Header / Profile
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            Text("Deine Musik und Entdeckungen im Überblick")
                                .font(.subheadline)
                                .foregroundColor(.portTextSecondary)
                        }
                        Spacer()
                        NavigationLink(destination: AccountSettingsView()) {
                            Image(systemName: "person.crop.circle")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)

                    // Continue Listening Chip
                    HomeContinueChip()
                        .padding(.horizontal)

                    // Featured Shelves
                    HomeStationsShelf()

                    ForYouShelves()

                    NewShelves()
                }
                .padding(.bottom, 120)
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadHomeData()
        }
    }
}
