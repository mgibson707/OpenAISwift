//
//  Created by Adam Rush - OpenAISwift
//

import Foundation

class Command: Encodable {
    var prompt: String
    var model: String
    var maxTokens: Int
    var stream: Bool

    
    init(prompt: String, model: String, maxTokens: Int, stream: Bool = false) {
        self.prompt = prompt
        self.model = model
        self.maxTokens = maxTokens
        self.stream = stream

    }
    
    enum CodingKeys: String, CodingKey {
        case prompt
        case model
        case maxTokens = "max_tokens"
        case stream
    }
}
