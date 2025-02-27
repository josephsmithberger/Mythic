//
//  GameListCard.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/20/24.
//

import SwiftUI
import CachedAsyncImage

struct GameListCard: View {
    @ObservedObject var viewModel: GameCardVM = .init()

    @Binding var game: Game
    @ObservedObject private var operation: GameOperation = .shared
    @State private var isHoveringOverDestructiveButton: Bool = false

    @State private var isImageEmpty: Bool = true

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.background)
            .frame(idealHeight: 120)
            .overlay {
                CachedAsyncImage(url: URL(string: Legendary.getImage(of: game, type: .normal))) { phase in
                    switch phase {
                    case .empty:
                        /*
                         Image(nsImage: workspace.icon(forFile: game.path ?? ""))
                         .resizable()
                         .clipShape(.rect(cornerRadius: 20))
                         .blur(radius: 20)
                         */

                        RoundedRectangle(cornerRadius: 20)
                            .fill(.background)

                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .blur(radius: 20.0)
                        image
                            .resizable()
                            .blur(radius: 20.0)
                            .clipShape(.rect(cornerRadius: 20))
                            .modifier(FadeInModifier())
                            .onAppear {
                                withAnimation { isImageEmpty = false }
                            }
                    case .failure:
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.windowBackground)
                            .overlay { Image(systemName: "exclamationmark.triangle.fill") }
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                    @unknown default:
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.windowBackground)
                            .overlay { Image(systemName: "questionmark.circle.fill") }
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                    }
                }
                .ignoresSafeArea()

                HStack {
                    if isImageEmpty {
                        GameCard.FallbackImageCard(game: $game)
                            .frame(width: 70, height: 70)
                            .padding()
                    }

                    VStack(alignment: .leading) {
                        Text(game.title)
                            .font(.system(.title, weight: .bold))

                        HStack {
                            GameCardVM.SharedViews.SubscriptedInfoView(game: $game)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal)

                    Spacer()

                    GameCardVM.SharedViews.ButtonsView(game: $game)
                        .padding(.trailing)
                }
            }
    }
}

#Preview {
    GameListCard(game: .constant(.init(source: .local, title: "MRAAAH")))
        .environmentObject(NetworkMonitor())
}
