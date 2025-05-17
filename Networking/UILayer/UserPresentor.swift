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
        isLoading = true // Set loading state
        errorMessage = nil // Clear previous errors
        user = nil // Clear previous user data

        do {
            let fetchedUser = try await interactor.getUser(username: username).firstValue() // Assuming firstValue helper exists

            print("Received user in Presenter (async): \(fetchedUser.login)")
            self.user = fetchedUser // Update the @Published property
            isLoading = false // Set loading state on successful completion
        } catch {
            // Handle errors from the publisher
            isLoading = false // Set loading state on failure
            print("User load failed (async): \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription // Display error to user
        }
    }
}

