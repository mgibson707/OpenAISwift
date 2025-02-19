//
//  Created by Adam Rush - OpenAISwift
//

import Foundation

class Command: Encodable {
    var prompt: String
    var model: String
    var maxTokens: Int
    var stream: Bool
    var echo: Bool
    var stop: [String]?

    
    init(prompt: String, model: String, maxTokens: Int, stream: Bool = false, stop: [String]? = nil, echo: Bool = false) {
        self.prompt = prompt
        self.model = model
        self.maxTokens = maxTokens
        self.stream = stream
        self.echo = echo
        self.stop = stop

    }
    
    enum CodingKeys: String, CodingKey {
        case prompt
        case model
        case maxTokens = "max_tokens"
        case stream
        case echo
        case stop
    }
}
