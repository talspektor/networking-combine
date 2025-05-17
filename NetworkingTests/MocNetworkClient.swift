//
//  MocNetworkClient.swift
//  Networking
//
//  Created by Tal talspektor on 5/17/25.
//

import XCTest
import Combine
import Foundation
@testable import Networking

class MockNetworkClient: NetworkClient {
    // This property is required by the NetworkClient protocol
    var networkClient: NetworkClient { self }

    // This closure will be set by the test case to control the output
    // It takes a NetworkRequest (to potentially check the request being made)
    // and returns a publisher that emits the mock response or error.
    var mockResponse: ((any NetworkRequest) -> AnyPublisher<(Data, HTTPURLResponse), NetworkError>)?

    // Implement the performRequest method required by NetworkClient
    func performRequest<Request: NetworkRequest>(_ request: Request) -> AnyPublisher<(Data, HTTPURLResponse), NetworkError> {
        // Use the closure to provide the mock response
        guard let mockResponse = mockResponse else {
            // If the mockResponse closure is not set, fail the test
            XCTFail("Mock response not set for NetworkClient")
            return Fail(error: NetworkError.unknownError).eraseToAnyPublisher()
        }
        return mockResponse(request)
    }
}
