//
//  UserInteractor.swift
//  Networking
//
//  Created by Tal talspektor on 5/17/25.
//

import Foundation
import Combine

protocol Interactor {
    var networkClient: NetworkClient { get }
}

protocol UserFetcher: Interactor {
    func getUser(username: String) -> AnyPublisher<GitHubUser, Error>
}

class UserInteractor: ObservableObject, UserFetcher {
        
    let networkClient: NetworkClient
    private var cancellables = Set<AnyCancellable>()
    
    init(networkClient: NetworkClient) {
        self.networkClient = networkClient
    }
    
    func getUser(username: String) -> AnyPublisher<GitHubUser, Error> {
        
        return networkClient.performRequest(GetUserRequest(username: username))
            .tryMap { data, response in
                let statusCode = response.statusCode
                print("Received response with status code: \(statusCode)")
                
                if (200...299).contains(statusCode) {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    return try decoder.decode(GitHubUser.self, from: data)
                } else {
                    // Handle server-side errors or other non-2xx status codes
                    // Attempt to decode a custom server error if expected
                    do {
                        let serverError = try JSONDecoder().decode(ServerError.self, from: data)
                        throw serverError // Throw the custom server error
                    } catch {
                        // If decoding the custom error fails, or it's a generic non-2xx,
                        // throw a more general error including the status code.
                        // You might want a more specific error type here.
                        throw NSError(domain: "ServerError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(statusCode)"])
                    }
                }
            }
            .mapError { error in
                // Map any upstream errors (NetworkError or decoding/server errors)
                // to the Error type expected by the publisher.
                // You can refine this mapping based on your error handling strategy.
                if let networkError = error as? NetworkError {
                    return networkError // Pass through NetworkClient's errors
                } else if let serverError = error as? ServerError {
                    return serverError // Pass through decoded server errors
                }
                else {
                    return error // Pass through other errors (like decoding errors)
                }
            }
            .receive(on: RunLoop.main) // Deliver the final result on the main thread
            .eraseToAnyPublisher() // Erase the publisher type
        
        
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
