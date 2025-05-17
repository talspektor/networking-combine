//
//  UserInteractor.swift
//  Networking
//
//  Created by Tal talspektor on 5/17/25.
//

import Foundation
import Combine

protocol Iteractor {
    var networkClient: NetworkClient { get }
}

class UserInteractor: ObservableObject,  {
        
    let networkClient: NetworkClient
    var cancellables = Set<AnyCancellable>()
    
    init(networkClient: NetworkClientImp) {
        self.networkClient = networkClient
    }
    
    func getUseby(username: String) -> AnyPublisher<GitHubUser, Error> {
        
        return networkClient.performRequest(GetUserRequest(username: username))
            .tryMap { data, response in
                let statusCode = response.statusCode
                print("Received response with status code: \(statusCode)")
                
                if (200...299).contains(statusCode) {
                    // Decode the successful response
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase // Assuming GitHub API uses snake_case
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
            .receive(on: DispatchQueue.main) // Deliver the final result on the main thread
            .eraseToAnyPublisher() // Erase the publisher type
        
        
    }
}
