import XCTest
import Combine

@testable import OpenAISwift
var tester: OpenAISwift?

enum TestError: Error {
    case noTester
    case noPublisher
}

final class OpenAISwiftTests: XCTestCase {
    
    override class func setUp() {
        tester = OpenAISwift(authToken: Constants.openAIAPIKey)
    }
    
//    func testStreamer() throws {
//        guard let tester = tester else {XCTFail("No Tester"); throw TestError.noTester}
//        let expectedResponse = expectation(description: "Generated response text")
//
//        let source = try tester.configureStreaming(with: "Here's the thing about large larguage models,", maxTokens: 64)
//        source.start()
//        wait(for: [expectedResponse], timeout: 20)
//
//    }
    
    @available(iOS 16.0, *)
    func testStreamPubV2Async() async throws {
        guard let tester = tester else {XCTFail("No Tester"); throw TestError.noTester}
        //let expectedResponse = expectation(description: "Generated response text")
        
        guard let pub = tester.completionStreamPublisherv2(with: "Pretend you are a pirate teaching a class on large language models:", maxTokens: 128)?
        .compactMap(\.choices.first?.text).scan(String(), { accumulated, latest in
            return accumulated + latest
        }).eraseToAnyPublisher() else {
            XCTFail("No Publisher")
            throw TestError.noPublisher
        }
        
        for try await partial in pub.values {
            print(partial)
        }


    }
    
    
    func testStreamPubV2() throws {
        guard let tester = tester else {XCTFail("No Tester"); throw TestError.noTester}
        let expectedResponse = expectation(description: "Generated response text")
        
        var subs = Set<AnyCancellable>()
        let pub = tester.completionStreamPublisherv2(with: "If large language models were animals, they would be", maxTokens: 128)
        pub?.compactMap(\.choices.first?.text).scan(String(), { accumulated, latest in
            return accumulated + latest
        }).sink { completed in
            switch completed {
            case .failure(let err):
                print("Finished Pub with error: \(err)")
                XCTFail("stream finished with error")
            case .finished:
                print("Pub finished without error")
            }
            expectedResponse.fulfill()
        } receiveValue: { resObj in
            print(resObj)
        }.store(in: &subs)
        
        wait(for: [expectedResponse], timeout: 40)


    }
    
//    func testStreamPub() throws {
//        guard let tester = tester else {XCTFail("No Tester"); throw TestError.noTester}
//        let expectedResponse = expectation(description: "Generated response text")
//
//        var subs = Set<AnyCancellable>()
//        let pub = tester.completionStreamPublisher(with: "Write me a New York Times headline announcing a dog has been elected as president.", maxTokens: 64)
//        pub?.sink { completed in
//            switch completed {
//            case .failure(let err):
//                print("Finished Pub with error: \(err)")
//                XCTFail("stream finished with error")
//            case .finished:
//                print("Pub finished without error")
//            }
//            expectedResponse.fulfill()
//        } receiveValue: { resObj in
//            print(resObj ?? "nil")
//        }.store(in: &subs)
//
//        wait(for: [expectedResponse], timeout: 40)
//
//
//    }
    
    // Testing clusure based method. Uses XCTestExpectations to make test wait for result.
    func testExample() throws {
        guard let tester = tester else {XCTFail("No Tester"); throw TestError.noTester}
        let expectedResponse = expectation(description: "Generated response text")
        
        tester.sendCompletion(with: "Large language models such as GPT3 are best understood by", maxTokens: 16) { result in
            switch result {
            case .success(let success):
                XCTAssertNotNil(success.choices.first?.text)
                let responseText = success.choices.first?.text ?? "-N/A-"
                print(responseText)
                let attachment = XCTAttachment(string: responseText)
                attachment.lifetime = .keepAlways
                self.add(attachment)
            case .failure(let failure):
                print(failure)
                XCTFail("\(failure)")
            }
            expectedResponse.fulfill()
        }
        
        wait(for: [expectedResponse], timeout: 15)

    }
    
    // Testing futures based method. Test is async, so no XCTestExpectations are needed in this case.
    func testFuture() async throws {
        guard let tester = tester else {XCTFail("No Tester"); throw TestError.noTester}
        
        guard let responseText = try await tester.getCompletion(with: "Large language models such as GPT3 are best understood by", maxTokens: 16).value.choices.first?.text else {
            XCTFail("Nil Response")
            return
        }
        
        print(responseText)
        let attachment = XCTAttachment(string: responseText)
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }
    
    override class func tearDown() {
        tester = nil
    }
}
