//
//  UserInteractor.swift
//  Networking
//
//  Created by Tal talspektor on 5/17/25.
//

import Foundation
import Combine
import CombineGenericNetworking

protocol Interactor {
    var networkClient: NetworkClient { get }
}

protocol UserFetcher: Interactor {
    func getUserCombine(username: String) -> AnyPublisher<GitHubUser, Error>
}

class UserInteractor: ObservableObject, UserFetcher {
        
    let networkClient: NetworkClient
    private var cancellables = Set<AnyCancellable>()
    
    init(networkClient: NetworkClient) {
        self.networkClient = networkClient
    }
    
    func getUserCombine(username: String) -> AnyPublisher<GitHubUser, Error> {
        return networkClient.performRequestWithDecodedResponse(GetUserRequest(username: username))
            .tryMap { decodedResponse, _ in
                decodedResponse
            }
            .mapError { error in
                error
            }
            .eraseToAnyPublisher()
    }
}

// Helper extension to get the first value from a publisher as an async value
// This is a common pattern when bridging single-value publishers to async/await.
extension Publisher {
    func firstValue() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var finished = false // Track if the publisher has finished

            cancellable = self.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        if !finished {
                            // If finished without emitting a value, it's an unexpected scenario
                            continuation.resume(throwing: URLError(.badServerResponse)) // Or a more appropriate error
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel() // Cancel the subscription once completed or failed
                },
                receiveValue: { value in
                    if !finished {
                        finished = true // Mark as finished after receiving the first value
                        continuation.resume(returning: value)
                        cancellable?.cancel() // Cancel the subscription after the first value
                    }
                }
            )
        }
    }
}
