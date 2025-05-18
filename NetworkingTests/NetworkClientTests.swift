//
//  NetworkClientTests.swift
//  NetworkingTests
//
//  Created by Tal talspektor on 5/17/25.
//

import XCTest
import Combine
import Foundation
@testable import Networking

// MARK: - Mock URLSession Components

// Mock URLSessionDataTask to control task behavior
class MockURLSessionDataTask: URLSessionDataTask, @unchecked Sendable {
    private let closure: () -> Void

    init(closure: @escaping () -> Void) {
        self.closure = closure
        super.init()
    }

    // Override resume to execute the closure
    override func resume() {
        closure()
    }

    // Override cancel if your tests need to simulate cancellation
    override func cancel() {
        // Implement cancellation logic if necessary for specific test cases
    }
}

// Mock URLSession to control data task creation and completion
class MockURLSession: URLSession, @unchecked Sendable {
    // This property will be set by the test case to control the data, response, and error
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?

    // This closure captures the request and the completion handler
    var dataTaskCompletionHandler: ((Data?, URLResponse?, Error?) -> Void)?

    // Override dataTask(with:completionHandler:) to return our mock task and capture the handler
    override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        self.dataTaskCompletionHandler = completionHandler
        // Return a mock task that will call the completion handler when resumed
        return MockURLSessionDataTask { [weak self] in
            // Call the captured completion handler with the mock data, response, and error
            self?.dataTaskCompletionHandler?(self?.mockData, self?.mockResponse, self?.mockError)
        }
    }

    // Override dataTask(with:) for Combine support
//    override func dataTaskPublisher(for request: URLRequest) -> URLSession.DataTaskPublisher {
//        // Create a publisher that immediately emits the mock data, response, or error
//        return URLSession.DataTaskPublisher(request: request, session: self)
//    }
}


// MARK: - NetworkClientImp Tests

class NetworkClientImpTests: XCTestCase {

    var cancellables: Set<AnyCancellable>!
    var mockSession: MockURLSession!
    var networkClient: NetworkClient! // Testing the concrete implementation

    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        mockSession = MockURLSession()
        // Initialize the NetworkClientImp with the mock session
        networkClient = NetworkClientImp(session: mockSession)
    }

    override func tearDown() {
        cancellables = nil
        mockSession = nil
        networkClient = nil
        super.tearDown()
    }

    // MARK: - Test Cases for performRequest

    func testPerformRequest_Success() {
        // 1. Arrange: Set up the mock session for a successful response
        let expectedData = "{\"message\": \"Success\"}".data(using: .utf8)!
        let httpResponse = HTTPURLResponse(url: URL(string: "http://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!

        mockSession.mockData = expectedData
        mockSession.mockResponse = httpResponse
        mockSession.mockError = nil

        // Create a simple mock request (assuming GetUserRequest conforms to NetworkRequest)
        let request = GetUserRequest(username: "test") // Use a valid request object

        // 2. Act: Call the method being tested
        let expectation = XCTestExpectation(description: "Receive successful response")

        networkClient.performRequest(request)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    print("Test received finished completion.")
                    // 3. Assert: The publisher should complete successfully
                    expectation.fulfill()
                case .failure(let error):
                    // 3. Assert: The publisher should not fail
                    XCTFail("Test failed with unexpected error: \(error.localizedDescription)")
                    expectation.fulfill()
                }
            }, receiveValue: { data, response in
                // 3. Assert: Check the received data and response
                XCTAssertEqual(data, expectedData)
                XCTAssertEqual(response.statusCode, 200)
                print("Test received data and response.")
            })
            .store(in: &cancellables)

        // Wait for the expectation to be fulfilled
        wait(for: [expectation], timeout: 1.0)
    }

    func testPerformRequest_Non2xxResponseWithData() {
        // 1. Arrange: Set up the mock session for a non-2xx response with data
        let expectedData = "{\"error\": \"Not Found\"}".data(using: .utf8)!
        let httpResponse = HTTPURLResponse(url: URL(string: "http://example.com")!, statusCode: 404, httpVersion: nil, headerFields: nil)!

        mockSession.mockData = expectedData
        mockSession.mockResponse = httpResponse
        mockSession.mockError = nil

        let request = GetUserRequest(username: "test")

        // 2. Act: Call the method being tested
        let expectation = XCTestExpectation(description: "Receive non-2xx response with data")

        networkClient.performRequest(request)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    print("Test received finished completion.")
                    // 3. Assert: The publisher should complete successfully even with non-2xx
                    // because the client is designed to pass the response through.
                    expectation.fulfill()
                case .failure(let error):
                    // 3. Assert: The publisher should not fail for a non-2xx HTTP response
                    XCTFail("Test failed with unexpected error: \(error.localizedDescription)")
                    expectation.fulfill()
                }
            }, receiveValue: { data, response in
                // 3. Assert: Check the received data and response
                XCTAssertEqual(data, expectedData)
                XCTAssertEqual(response.statusCode, 404)
                print("Test received data and non-2xx response.")
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testPerformRequest_NetworkError() {
        // 1. Arrange: Set up the mock session for a network error
        let expectedError = URLError(.notConnectedToInternet)

        mockSession.mockData = nil
        mockSession.mockResponse = nil
        mockSession.mockError = expectedError

        let request = GetUserRequest(username: "test")

        // 2. Act: Call the method being tested
        let expectation = XCTestExpectation(description: "Receive network error")

        networkClient.performRequest(request)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    // 3. Assert: The publisher should not finish successfully
                    XCTFail("Test finished unexpectedly.")
                    expectation.fulfill()
                case .failure(let error):
                    // 3. Assert: Check the received network error
                    print("Test received expected error: \(error.localizedDescription)")
                    if case .requestFailed(let underlyingError) = error,
                       let urlError = underlyingError as? URLError {
                        XCTAssertEqual(urlError.code, expectedError.code)
                        expectation.fulfill()
                    } else {
                        XCTFail("Received unexpected error type: \(error)")
                        expectation.fulfill()
                    }
                }
            }, receiveValue: { data, response in
                // 3. Assert: No value should be received on error
                XCTFail("Received unexpected value.")
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testPerformRequest_InvalidURL() {
        // 1. Arrange: Create a request with an invalid URL
        // Assuming NetworkRequest has a way to represent an invalid URL,
        // or you can create a mock request that returns nil for url.
        struct InvalidURLRequest: NetworkRequest {
            typealias Response = GitHubUser
            var url: URL? { nil } // Simulate invalid URL
            var method: HTTPMethod { .get }
            var headers: [String: String]? { nil }
            var body: Data? { nil }
        }
        let request = InvalidURLRequest()

        // 2. Act: Call the method being tested
        let expectation = XCTestExpectation(description: "Receive invalid URL error")

        networkClient.performRequest(request)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    // 3. Assert: The publisher should not finish successfully
                    XCTFail("Test finished unexpectedly.")
                    expectation.fulfill()
                case .failure(let error):
                    // 3. Assert: Check the received invalid URL error
                    print("Test received expected error: \(error.localizedDescription)")
                    if case .invalidURL = error {
                        expectation.fulfill()
                    } else {
                        XCTFail("Received unexpected error type: \(error)")
                        expectation.fulfill()
                    }
                }
            }, receiveValue: { data, response in
                // 3. Assert: No value should be received on error
                XCTFail("Received unexpected value.")
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

     func testPerformRequest_InvalidResponse() {
         // 1. Arrange: Set up the mock session to return a non-HTTPURLResponse
         let expectedData = "some data".data(using: .utf8)!
         let nonHTTPResponse = URLResponse(url: URL(string: "http://example.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)

         mockSession.mockData = expectedData
         mockSession.mockResponse = nonHTTPResponse
         mockSession.mockError = nil

         let request = GetUserRequest(username: "test")

         // 2. Act: Call the method being tested
         let expectation = XCTestExpectation(description: "Receive invalid response error")

         networkClient.performRequest(request)
             .sink(receiveCompletion: { completion in
                 switch completion {
                 case .finished:
                     // 3. Assert: The publisher should not finish successfully
                     XCTFail("Test finished unexpectedly.")
                     expectation.fulfill()
                 case .failure(let error):
                     // 3. Assert: Check the received invalid response error
                     print("Test received expected error: \(error.localizedDescription)")
                     if case .invalidResponse = error {
                         expectation.fulfill()
                     } else {
                         XCTFail("Received unexpected error type: \(error)")
                         expectation.fulfill()
                     }
                 }
             }, receiveValue: { data, response in
                 // 3. Assert: No value should be received on error
                 XCTFail("Received unexpected value.")
             })
             .store(in: &cancellables)

         wait(for: [expectation], timeout: 1.0)
     }

    // Add more test cases as needed for different HTTP methods, headers, body, etc.
}
