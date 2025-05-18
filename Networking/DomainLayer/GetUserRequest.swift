//
//  GetUserRequest.swift
//  Networking
//
//  Created by Tal talspektor on 5/17/25.
//

import Foundation
import CombineGenericNetworking

// Define a request for fetching a user (conforming to the updated NetworkRequest protocol)
struct GetUserRequest: NetworkRequest {
    typealias Response = GitHubUser
    typealias ServerError = Networking.ServerError
    
    let username: String

    var url: URL? {
        URL(string: "https://api.github.com/users/\(username)")
    }

    var method: HTTPMethod { .get }
    var headers: [String: String]? { nil }
    var body: Data? { nil }
}
