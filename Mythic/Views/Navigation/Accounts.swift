//
//  Accounts.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/3/2024.
//

import SwiftUI
import SwordRPC

struct AccountsView: View {
    @State private var isSignOutConfirmationPresented: Bool = false
    @State private var isAuthViewPresented: Bool = false
    @State private var isHoveringOverDestructiveEpicButton: Bool = false
    @State private var signedIn: Bool = false
    
    @State private var isHoveringOverDestructiveSteamButton: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                // MARK: Epic Card
                RoundedRectangle(cornerRadius: 20)
                    .fill(.background)
                    .aspectRatio(4/3, contentMode: .fit)
                    .frame(width: 240)
                    .overlay(alignment: .top) {
                        VStack {
                            Image("EGFaceless")
                                .resizable()
                                .aspectRatio(1, contentMode: .fit)
                                .frame(width: 60)
                            
                            Spacer()
                            
                            VStack {
                                HStack {
                                    Text("Epic")
                                    Spacer()
                                }
                                
                                HStack {
                                    Text(signedIn ? "Signed in as \"\(Legendary.whoAmI())\"." : "Not signed in")
                                        .font(.bold(.title3)())
                                    Spacer()
                                }
                            }
                            
                            Button {
                                if signedIn {
                                    isSignOutConfirmationPresented = true
                                } else {
                                    isAuthViewPresented = true
                                }
                            } label: {
                                Image(systemName: signedIn ? "person.slash" : "person")
                                    .foregroundStyle(isHoveringOverDestructiveEpicButton ? .red : .primary)
                                    .padding(5)
                                
                            }
                            .clipShape(.circle)
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    isHoveringOverDestructiveEpicButton = (hovering && signedIn)
                                }
                            }
                            .sheet(isPresented: $isAuthViewPresented, onDismiss: { signedIn = Legendary.signedIn() }, content: {
                                AuthView(isPresented: $isAuthViewPresented)
                            })
                            .alert(isPresented: $isSignOutConfirmationPresented) {
                                Alert(
                                    title: .init("Are you sure you want to sign out from Epic?"),
                                    message: .init("This will sign you out of the account \"\(Legendary.whoAmI())\"."),
                                    primaryButton: .destructive(.init("Sign Out")) {
                                        Task.sync(priority: .high) {
                                            try? await Legendary.command(arguments: ["auth", "--delete"], identifier: "signout") { _  in }
                                        }
                                        
                                        signedIn = Legendary.signedIn()
                                    },
                                    secondaryButton: .cancel(.init("Cancel"))
                                )
                            }
                        }
                        .task { signedIn = Legendary.signedIn() }
                        .padding()
                    }
                
                // MARK: Steam Card
                RoundedRectangle(cornerRadius: 20)
                    .fill(.background)
                    .aspectRatio(4/3, contentMode: .fit)
                    .frame(width: 240)
                    .overlay(alignment: .top) {
                        VStack {
                            Image("Steam")
                                .resizable()
                                .aspectRatio(1, contentMode: .fit)
                                .frame(width: 60)
                            
                            Spacer()
                            
                            VStack {
                                HStack {
                                    Text("Steam")
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("Coming Soon")
                                        .font(.bold(.title3)())
                                    Spacer()
                                }
                            }
                            
                            Button {
                                //
                            } label: {
                                Image(systemName: /* signedIn ? "person.slash" : */ "person")
                                    .foregroundStyle(isHoveringOverDestructiveSteamButton ? .red : .primary)
                                    .padding(5)
                                
                            }
                            .clipShape(.circle)
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    isHoveringOverDestructiveSteamButton = (hovering && signedIn)
                                }
                            }
                        }
                        .padding()
                    }
                    .disabled(true)
                
                Spacer() // push to top corner..
            }
            .padding()
            .navigationTitle("Accounts")
            .task(priority: .background) {
                discordRPC.setPresence({
                    var presence: RichPresence = .init()
                    presence.details = "Currently in the accounts section."
                    presence.state = "Checking out all their accounts"
                    presence.timestamps.start = .now
                    presence.assets.largeImage = "macos_512x512_2x"
                    
                    return presence
                }())
            }
            
            Spacer() // push to top corner..
        }
    }
}

#Preview {
    AccountsView()
}
