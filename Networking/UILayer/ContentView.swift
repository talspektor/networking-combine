//
//  ContentView.swift
//  Networking
//
//  Created by Tal talspektor on 5/17/25.
//

import SwiftUI

struct ContentView: View {
    
    @State private var user: GitHubUser?
    @StateObject private var interactor = UserInteractor(networkClient: NetworkClient())
    
    var body: some View {
        VStack {
            
            AsyncImage(url: URL(string: interactor.user?.avatarUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .foregroundStyle(.secondary)
            }
            .frame(width: 120, height: 120)
            
            Text(interactor.user?.login ?? "Login placeholder")
                .bold()
                .font(.title3)
            
            Text(interactor.user?.bio ?? "Bio placeholder")
            
            Spacer()

        }
        .padding()
        .task {
            do {
//                user = try await getUser()
                
                 interactor.getUseby(username: "talspektor")
            } catch GHError.invalidURL {
                print("")
            }
        }
    }
    
    func getUser() async throws -> GitHubUser {
        let endpoint = "https://api.github.com/users/talspektor"
        
        do {
            return try await getRequest(type: GitHubUser.self, endpoint: endpoint)
        } catch {
            throw error
        }
    }
    
    func getRequest<T: Decodable>(type: T.Type, endpoint: String) async throws -> T {
        guard let url = URL(string: endpoint) else {
            throw 
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(type.self, from: data)
        } catch {
            throw APIError.invalidData
        }
    }
}

#Preview {
    ContentView()
}
