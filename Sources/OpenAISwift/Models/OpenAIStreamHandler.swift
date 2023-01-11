//
//  OpenAIStreamHandler.swift
//  
//
//  Created by Matt on 1/4/23.
//

import Foundation
import LDSwiftEventSource
import Combine

protocol StreamEventHandler: EventHandler {
    var finishReason: Choice.FinishReason? { get set }
    func onCompletedOpenAIStreaming(with generationFinishReason: Choice.FinishReason?)
}

extension StreamEventHandler {
    
    public func onOpened() {
        print("[OpenAIStreamHandler] Stream opened." + "\n")
        if self.finishReason != nil {
            print("Warning! started stream with an existing finish reason.")
        }
    }
    
    public func onClosed() {
        print("[OpenAIStreamHandler] Stream closed." + "\n")
    }
    
    public func onMessage(eventType: String, messageEvent: LDSwiftEventSource.MessageEvent) {
        
    }


    public func onComment(comment: String) {
        print("[OpenAIStreamHandler] Stream received comment: \(comment)" + "\n")

    }
    
    func onError(error: Error) {
        self.currentStreamMessage.send(completion: .failure(error))
    }
 
}

class OpenAIStreamHandler: StreamEventHandler {
    
    /// `EventHandler` protocol conformance
    public var currentStreamMessage = CurrentValueSubject<LDSwiftEventSource.MessageEvent?, Error>(nil)
    
    /// `StreamEventHandler` protocol conformance
    var finishReason: Choice.FinishReason?

    
    // publisher that decodes currentStreamMessage to OpenAI objects
    // - checks for [DONE] in the message data, terminating the stream when it is found
    // -
    lazy var currentStreamObject: AnyPublisher<OpenAI, Error> = {
        currentStreamMessage.compactMap({$0}).compactMap{ (messageEvent: MessageEvent) -> OpenAI? in
            // check for OpenAI [DONE], if recieved, call `onGenerationStreamComplete` handler and fast exit.
            if messageEvent.data.hasPrefix("[DONE]") {
                print("OpenAI Generation stream [DONE] sending SSE events. Stream will close now...")
                
                // onCompleted will send `.finished` completion event to `currentStreamMessage` aka this publishers upstream.
                self.onCompletedOpenAIStreaming(with: self.finishReason)
                
                // Return nil to prevent passing the done event downstream as a recieveValue event,
                // instead we want to send a completion event to terminate the publisher stream.
                return nil
            }
            // decode response JSON. First turn JSON string to Data, then decode data to codable object type `OpenAI`
            if let messageData = messageEvent.data.data(using: .utf8, allowLossyConversion: false) {
                if let openAIResp = try? JSONDecoder().decode(OpenAI.self, from: messageData) {
                    // check for a `fninish_reason` and store if it exists.
                    // This will be returned with onCompletedOpenAIStreaming handler.
                    if let finishReason = openAIResp.choices.first?.finishReason {
                        self.finishReason = finishReason
                    }
                    
                    // decoded OpenAI object to go downstream
                    return openAIResp
                }
            }
            return nil
            
        }.eraseToAnyPublisher()
    }()

    /// `StreamEventHandler` protocol conformance
    func onCompletedOpenAIStreaming(with generationFinishReason: Choice.FinishReason?) {
        //todo
        print("finished stream with \(generationFinishReason == nil ? "nil/unknown reason" : generationFinishReason!.rawValue) 🏁")
        self.currentStreamMessage.send(completion: .finished)
    }


    // `onError(error: Error)` default protocol implementation automatically sends errors to StreamEventHandler's currentStreamMessage

    
    
    
    
}
