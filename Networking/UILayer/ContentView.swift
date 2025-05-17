//
//  ContentView.swift
//  Networking
//
//  Created by Tal talspektor on 5/17/25.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var presentor = UserPresentor(interactor: UserInteractor(networkClient: NetworkClientImp()))
    
    var body: some View {
        VStack {
            
            AsyncImage(url: URL(string: presentor.user?.avatarUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .foregroundStyle(.secondary)
            }
            .frame(width: 120, height: 120)
            
            Text(presentor.user?.login ?? "Login placeholder")
                .bold()
                .font(.title3)
            
            Text(presentor.user?.bio ?? "Bio placeholder")
            
            Spacer()
            
            if let errorMessage = presentor.errorMessage {
                Text(errorMessage)
                    .font(.title)
            }

        }
        .padding()
        .task {
            await presentor.loadUser(username: "talspektor")
        }
    }
}

#Preview {
    ContentView()
}
