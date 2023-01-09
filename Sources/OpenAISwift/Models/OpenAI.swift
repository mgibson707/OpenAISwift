//
//  Created by Adam Rush - OpenAISwift
//

import Foundation

public struct OpenAI: Codable {
    public let id: String
    public let object: String
    public let model: String?
    public let choices: [Choice]
}

public struct Choice: Codable {
    public let index: Int
    
    public let text: String
    public let finishReason: FinishReason?
    
    enum CodingKeys: String, CodingKey {
        case index
        case text
        case finishReason = "finish_reason"
    }
    
    public enum FinishReason: String, Codable {
        case stop
        case length
    }
}
