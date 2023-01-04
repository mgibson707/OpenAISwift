import XCTest
@testable import OpenAISwift
var tester: OpenAISwift?

enum TestError: Error {
    case noTester
}

final class OpenAISwiftTests: XCTestCase {
    
    override class func setUp() {
        tester = OpenAISwift(authToken: Constants.openAIAPIKey)
    }
    
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
