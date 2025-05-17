//
//  DTO.swift
//  Networking
//
//  Created by Tal talspektor on 5/17/25.
//

import Foundation

struct GitHubUser: Codable {
    let login: String
    let avatarUrl: String
    let bio: String
}

// Define a simple Decodable struct for a user (used by the caller for decoding)
struct User: Decodable {
    let id: Int
    let name: String
    let username: String
    let email: String
}

// Define a potential custom server error response struct
struct ServerError: Decodable, Error {
    let code: Int
    let message: String

    var localizedDescription: String {
        return "Server Error \(code): \(message)"
    }
}
