//
//  UserPresentorTests.swift
//  Networking
//
//  Created by Tal talspektor on 5/17/25.
//

import XCTest
import Combine
import Foundation
import SwiftUI // Needed for ObservableObject and @Published
@testable import Networking

// Assume these types are defined and accessible for testing from your main app target
// by being marked with 'public' access control:
// public struct GitHubUser: Decodable, Identifiable { ... }
// public enum NetworkError: Error { ... }
// public protocol UserFetcher { ... } // The protocol UserPresentor depends on
// public class UserPresentor: ObservableObject { ... } // The class being tested
// public struct ServerError: Decodable, Error { ... }

// Define a mock UserFetcher for testing UserPresentor
// This mock conforms to the public UserFetcher protocol from your app target
public class MockUserFetcher: UserFetcher {
    public let networkClient: any Networking.NetworkClient
    // Marked as public
    // This closure will be set by the test case to control the output of getUser
    var mockPublisher: ((String) -> AnyPublisher<GitHubUser, Error>)?
    
    init(networkClient: any Networking.NetworkClient) {
        self.networkClient = networkClient
    }

    // Implement the getUser method required by UserFetcher
    public func getUser(username: String) -> AnyPublisher<GitHubUser, Error> {
        // Use the closure to provide the mock publisher
        guard let mockPublisher = mockPublisher else {
            XCTFail("Mock publisher not set for UserFetcher")
            // Assuming NetworkError is public and accessible
            return Fail(error: NetworkError.unknownError).eraseToAnyPublisher()
        }
        return mockPublisher(username)
    }
}

// MARK: - UserPresentor Tests

class UserPresentorTests: XCTestCase {

    var cancellables: Set<AnyCancellable>!
    var mockUserFetcher: MockUserFetcher!
    var userPresentor: UserPresentor! // Testing the concrete Presentor

    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        mockUserFetcher = MockUserFetcher(networkClient: MockNetworkClient())
        // Initialize the real UserPresentor with the mock UserFetcher
        userPresentor = UserPresentor(interactor: mockUserFetcher)
    }

    override func tearDown() {
        cancellables = nil
        mockUserFetcher = nil
        userPresentor = nil
        super.tearDown()
    }

    // MARK: - Test Cases for loadUser(username:)

    @MainActor func testLoadUser_Success() async {
        // 1. Arrange: Set up the mock UserFetcher for a successful user fetch
        let expectedUser = GitHubUser(login: "testuser", avatarUrl: "http://example.com/avatar.png", bio: "A test user")

        mockUserFetcher.mockPublisher = { username in
            // You can check the username passed to the fetcher here
            return Just(expectedUser) // Return a publisher that immediately emits the expected user
                .setFailureType(to: Error.self) // Specify the failure type as Error
                .eraseToAnyPublisher()
        }

        // 2. Act: Call the method being tested
        let expectation = XCTestExpectation(description: "UserPresentor updates user on success")
        // Observe the @Published user property
        userPresentor.$user
            .dropFirst() // Ignore the initial nil value
            .sink { user in
                // 3. Assert: Check that the user property was updated correctly
                XCTAssertEqual(user?.login, expectedUser.login)
                print("Test received updated user in Presentor.")
                expectation.fulfill() // Fulfill the expectation when the user is updated
            }
            .store(in: &cancellables)

        // Also observe isLoading if you add that property back to Presentor
        // userPresentor.$isLoading
        //     .sink { isLoading in
        //         print("isLoading changed to: \(isLoading)")
        //         // Add assertions for isLoading state changes
        //     }
        //     .store(in: &cancellables)

        await userPresentor.loadUser(username: "testuser")

        // Wait for the expectation to be fulfilled
        wait(for: [expectation], timeout: 1.0)

        // Optional: Add assertions for final state after waiting
        XCTAssertNil(userPresentor.errorMessage) // Should be nil on success
        // XCTAssertFalse(userPresentor.isLoading) // Should be false on completion
    }

    @MainActor func testLoadUser_Failure() async {
        // 1. Arrange: Set up the mock UserFetcher for a failed user fetch
        let expectedError = NSError(domain: "MockErrorDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch user"])

        mockUserFetcher.mockPublisher = { username in
            return Fail(error: expectedError) // Return a publisher that immediately fails
                .eraseToAnyPublisher()
        }

        // 2. Act: Call the method being tested
        let expectation = XCTestExpectation(description: "UserPresentor updates error message on failure")
         // Observe the @Published errorMessage property
        userPresentor.$errorMessage
            .dropFirst() // Ignore the initial nil value
            .sink { errorMessage in
                // 3. Assert: Check that the errorMessage property was updated correctly
                XCTAssertEqual(errorMessage, expectedError.localizedDescription)
                print("Test received updated error message in Presentor.")
                expectation.fulfill() // Fulfill the expectation when the error message is updated
            }
            .store(in: &cancellables)

        // Also observe isLoading if you add that property back to Presentor
        // userPresentor.$isLoading
        //     .sink { isLoading in
        //         print("isLoading changed to: \(isLoading)")
        //         // Add assertions for isLoading state changes
        //     }
        //     .store(in: &cancellables)

        await userPresentor.loadUser(username: "anyuser")

        // Wait for the expectation to be fulfilled
        wait(for: [expectation], timeout: 1.0)

        // Optional: Add assertions for final state after waiting
        XCTAssertNil(userPresentor.user) // Should be nil on failure
        // XCTAssertFalse(userPresentor.isLoading) // Should be false on completion
    }

    // Add more test cases for isLoading state changes, different error types, etc.
}
