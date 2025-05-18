//
//  NetworkClient.swift
//  Networking
//
//  Created by Tal talspektor on 5/17/25.
//

//import Foundation
//import Combine
//
//protocol NetworkClient {
//    func performRequest<Request: NetworkRequest>(_ request: Request) -> AnyPublisher<(Data, HTTPURLResponse), NetworkError>
//}
//
//// Generic Network Client using Combine
//class NetworkClientImp: NetworkClient {
//
//    private let session: URLSession
//
//    init(session: URLSession = .shared) {
//        self.session = session
//    }
//
//    /// Performs a network request and returns a Combine publisher with raw data and response.
//    /// The caller is responsible for checking the status code and decoding the data.
//    /// - Parameter request: The NetworkRequest to perform.
//    /// - Returns: A publisher that emits a tuple of Data and HTTPURLResponse, or a NetworkError.
//    func performRequest<Request: NetworkRequest>(_ request: Request) -> AnyPublisher<(Data, HTTPURLResponse), NetworkError> {
//        guard let url = request.url else {
//            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
//        }
//
//        var urlRequest = URLRequest(url: url)
//        urlRequest.httpMethod = request.method.rawValue
//        urlRequest.allHTTPHeaderFields = request.headers
//        urlRequest.httpBody = request.body
//
//        // Use URLSession's dataTaskPublisher for Combine integration
//        return session.dataTaskPublisher(for: urlRequest)
//            .tryMap { data, response in
//                // Ensure the response is an HTTPURLResponse
//                guard let httpResponse = response as? HTTPURLResponse else {
//                    throw NetworkError.invalidResponse // Still throw if it's not an HTTP response
//                }
//                // Pass both data and response through, regardless of status code
//                return (data, httpResponse)
//            }
//            .mapError { error in
//                // Map potential URLSession errors to our custom NetworkError type
//                if let networkError = error as? NetworkError {
//                    return networkError
//                } else {
//                    return NetworkError.requestFailed(error)
//                }
//            }
//            .eraseToAnyPublisher() // Erase the publisher type for flexibility
//    }
//}

