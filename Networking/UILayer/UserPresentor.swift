//
//  UserPresentor.swift
//  Networking
//
//  Created by Tal talspektor on 5/17/25.
//

import Foundation

class UserPresentor: ObservableObject {

    @Published var user: GitHubUser?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false // Added isLoading state

    let interactor: UserFetcher

    init(interactor: UserFetcher) {
        self.interactor = interactor
    }

    @MainActor func loadUser(username: String) async {
        isLoading = true
        errorMessage = nil
        user = nil

        do {
            let fetchedUser = try await interactor.getUser(username: username).firstValue() // Assuming firstValue helper exists

            print("Received user in Presenter (async): \(fetchedUser.login)")
            self.user = fetchedUser
            isLoading = false
        } catch {
            // Handle errors from the publisher
            isLoading = false // Set loading state on failure
            print("User load failed (async): \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription // Display error to user
        }
    }
}

