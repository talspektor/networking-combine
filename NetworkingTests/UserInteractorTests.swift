//
//  UserInteractorTests.swift
//  NetworkingTests
//
//  Created by Tal talspektor on 5/17/25.
//

import XCTest
import Combine
import Foundation
@testable import Networking

// Assume these types are defined and accessible for testing from your main app target
// by being marked with 'public' access control:
// public struct GitHubUser: Decodable, Identifiable { ... }
// public enum NetworkError: Error { ... }
// public protocol NetworkRequest { ... }
// public enum HTTPMethod: String { ... }
// public protocol UserFetcher { ... } // The protocol UserInteractor conforms to
// public class UserInteractor: ObservableObject, UserFetcher { ... } // The class being tested
// public struct ServerError: Decodable, Error { ... }
// public protocol NetworkClient { ... } // The protocol NetworkClientImp conforms to
// public struct GetUserRequest: NetworkRequest { ... } // The request type used by Interactor

// Define a mock NetworkClient for testing UserInteractor
// This mock conforms to the public NetworkClient protocol from your app target
class MockNetworkClientForInteractor: NetworkClient {
    // This closure will be set by the test case to control the output
    // It takes a NetworkRequest and returns a publisher that emits the mock response or error.
    var mockResponse: ((any NetworkRequest) -> AnyPublisher<(Data, HTTPURLResponse), NetworkError>)?

    // Implement the performRequest method required by NetworkClient
    func performRequest<Request: NetworkRequest>(_ request: Request) -> AnyPublisher<(Data, HTTPURLResponse), NetworkError> {
        // Use the closure to provide the mock response
        guard let mockResponse = mockResponse else {
            XCTFail("Mock response not set for NetworkClient")
            return Fail(error: NetworkError.unknownError).eraseToAnyPublisher()
        }
        return mockResponse(request)
    }
}

// MARK: - UserInteractor Tests

class UserInteractorTests: XCTestCase {

    var cancellables: Set<AnyCancellable>!
    var mockNetworkClient: MockNetworkClientForInteractor!
    var userInteractor: UserInteractor! // Testing the concrete Interactor

    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        mockNetworkClient = MockNetworkClientForInteractor()
        // Initialize the real UserInteractor with the mock NetworkClient
        userInteractor = UserInteractor(networkClient: mockNetworkClient)
    }

    override func tearDown() {
        cancellables = nil
        mockNetworkClient = nil
        userInteractor = nil
        super.tearDown()
    }

    // MARK: - Test Cases for getUser(username:)

    func testGetUser_Success() {
        // 1. Arrange: Set up the mock NetworkClient for a successful API call.
        let expectedUser = GitHubUser(login: "testuser", avatarUrl: "http://example.com/avatar.png", bio: "A test user")
        // Encode the expected user object into JSON data (snake_case for GitHub API).
        let jsonData = """
        {
            "id": 1,
            "login": "testuser",
            "avatar_url": "http://example.com/avatar.png",
            "bio": "A test user"
        }
        """.data(using: .utf8)!
        let httpResponse = HTTPURLResponse(url: URL(string: "http://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!

        mockNetworkClient.mockResponse = { request in
            // You can check the request username here if needed
            return Just((jsonData, httpResponse))
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }

        // 2. Act: Call the method being tested
        let expectation = XCTestExpectation(description: "Receive user data successfully")

        userInteractor.getUser(username: "testuser")
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    print("Test received finished completion.")
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("Test failed with unexpected error: \(error.localizedDescription)")
                    expectation.fulfill()
                }
            }, receiveValue: { user in
                // 3. Assert: Check the received user data
                XCTAssertEqual(user.login, expectedUser.login)
                XCTAssertEqual(user.avatarUrl, expectedUser.avatarUrl)
                XCTAssertEqual(user.bio, expectedUser.bio)
                print("Test received user value: \(user.login)")
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }
    // This test will fail - this logic is not implemented in the app yet
    
    func testGetUser_ServerError_DecodableError() {
        // 1. Arrange: Set up the mock NetworkClient for a server error with a decodable error body.
        let serverErrorMessage = "User not found"
        let serverErrorData = """
        {
            "code": 404,
            "message": "\(serverErrorMessage)"
        }
        """.data(using: .utf8)!
        let httpResponse = HTTPURLResponse(url: URL(string: "http://example.com")!, statusCode: 404, httpVersion: nil, headerFields: nil)!

        mockNetworkClient.mockResponse = { request in
            return Just((serverErrorData, httpResponse))
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }

        // 2. Act: Call the method being tested
        let expectation = XCTestExpectation(description: "Receive server error")

        userInteractor.getUser(username: "nonexistentuser")
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    XCTFail("Test finished unexpectedly.")
                case .failure(let error):
                    // 3. Assert: Check the received error is the decoded ServerError
                    print("Test received completion with error: \(error.localizedDescription)")
                    if let serverError = error as? ServerError {
                        XCTAssertEqual(serverError.code, 404)
                        XCTAssertEqual(serverError.message, serverErrorMessage)
                         print("Test received expected ServerError.")
                    } else {
                         XCTFail("Received unexpected error type: \(error)")
                    }
                    expectation.fulfill()
                }
            }, receiveValue: { user in
                XCTFail("Received unexpected user value: \(user)")
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testGetUser_ServerError_NonDecodableError() {
        // 1. Arrange: Set up the mock NetworkClient for a server error with a non-decodable error body.
        let rawErrorData = "<html><body><h1>Internal Server Error</h1></body></html>".data(using: .utf8)!
        let httpResponse = HTTPURLResponse(url: URL(string: "http://example.com")!, statusCode: 500, httpVersion: nil, headerFields: nil)!

        mockNetworkClient.mockResponse = { request in
            return Just((rawErrorData, httpResponse))
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }

        // 2. Act: Call the method being tested
        let expectation = XCTestExpectation(description: "Receive generic server error")

        userInteractor.getUser(username: "anyuser")
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    XCTFail("Test finished unexpectedly.")
                case .failure(let error):
                    // 3. Assert: Check the received error is a generic NSError for the status code
                    print("Test received completion with error: \(error.localizedDescription)")
                     if let nsError = error as NSError? {
                         XCTAssertEqual(nsError.domain, "ServerError")
                         XCTAssertEqual(nsError.code, 500)
                         XCTAssertTrue(nsError.localizedDescription.contains("Server returned status code 500"))
                         print("Test received expected NSError for server error.")
                    }
                    else {
                         XCTFail("Received unexpected error type: \(error)")
                    }
                    expectation.fulfill()
                }
            }, receiveValue: { user in
                XCTFail("Received unexpected user value: \(user)")
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }


    func testGetUser_NetworkError() {
        // 1. Arrange: Set up the mock NetworkClient for a network failure.
        let expectedError = NetworkError.requestFailed(URLError(.notConnectedToInternet))

        mockNetworkClient.mockResponse = { request in
            return Fail(error: expectedError)
                .eraseToAnyPublisher()
        }

        // 2. Act: Call the method being tested
        let expectation = XCTestExpectation(description: "Receive network error")

        userInteractor.getUser(username: "anyuser")
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    XCTFail("Test finished unexpectedly.")
                case .failure(let error):
                    // 3. Assert: Check the received error is the NetworkError
                    print("Test received completion with error: \(error.localizedDescription)")
                    if let networkError = error as? NetworkError {
                         if case .requestFailed(let underlyingError) = networkError,
                            let urlError = underlyingError as? URLError {
                             XCTAssertEqual(urlError.code, URLError.notConnectedToInternet)
                             print("Test received expected NetworkError.")
                         } else {
                              XCTFail("Received unexpected NetworkError type: \(networkError)")
                         }
                    } else {
                        XCTFail("Received unexpected error type: \(error)")
                    }
                    expectation.fulfill()
                }
            }, receiveValue: { user in
                XCTFail("Received unexpected user value: \(user)")
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testGetUser_DecodingError_SuccessResponse() {
        // 1. Arrange: Set up the mock NetworkClient for a successful response with invalid JSON for GitHubUser.
        let invalidJsonData = "{\"id\": \"not an int\", \"login\": \"testuser\"}".data(using: .utf8)! // Invalid JSON
        let httpResponse = HTTPURLResponse(url: URL(string: "http://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!

        mockNetworkClient.mockResponse = { request in
            return Just((invalidJsonData, httpResponse))
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }

        // 2. Act: Call the method being tested
        let expectation = XCTestExpectation(description: "Receive decoding error for success response")

        userInteractor.getUser(username: "testuser")
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    XCTFail("Test finished unexpectedly.")
                case .failure(let error):
                    // 3. Assert: Check the received error is a decoding error
                    print("Test received completion with error: \(error.localizedDescription)")
                    XCTAssertTrue(error is DecodingError)
                    print("Test received expected DecodingError.")
                    expectation.fulfill()
                }
            }, receiveValue: { user in
                XCTFail("Received unexpected user value: \(user)")
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    // Add more test cases as needed for other scenarios
}

