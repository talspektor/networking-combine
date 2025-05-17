//
//  NetworkRequst.swift
//  Networking
//
//  Created by Tal talspektor on 5/17/25.
//

import Foundation


protocol NetworkRequest {
    associatedtype Response: Decodable // The expected response type must be Decodable
    var url: URL? { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var body: Data? { get }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
