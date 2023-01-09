//
//  OpenAIStreamHandler.swift
//  
//
//  Created by Matt on 1/4/23.
//

import Foundation
import LDSwiftEventSource
import Combine

public protocol StreamEventHandler: EventHandler {
    var finishReason: Choice.FinishReason? { get set }
    mutating func onOpenAIStreamingGeneration(streamingMessage: OpenAI)
    func onGenerationStreamCompleted(with finishReason: Choice.FinishReason?)
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
    
    
    // don't implement `onMessage` in concrete classes. this protocol is already openai only, so specific handling will happen here.
    public mutating func onMessage(eventType: String, messageEvent: LDSwiftEventSource.MessageEvent) {
        //print("[OpenAIStreamHandler] Stream received \(eventType) event: \(messageEvent)." + "\n")
        
        // check for OpenAI [DONE], if recieved, call `onGenerationStreamComplete` handler and fast exit.
        if messageEvent.data.hasPrefix("[DONE]") {
            print("OpenAI Generation stream finished successfully. Will close stream now...")
            self.onGenerationStreamCompleted(with: self.finishReason)
            return
        }
        
        // decode response JSON. First turn JSON string to Data, then decode data to codable object type `OpenAI`
        if let messageData = messageEvent.data.data(using: .utf8, allowLossyConversion: false) {
            
            if let openAIResp = try? JSONDecoder().decode(OpenAI.self, from: messageData) {
                // send decoded response OpenAI object to openAI response handler
                self.onOpenAIStreamingGeneration(streamingMessage: openAIResp)
                
                // check for a `fninish_reason` and store if it exists.
                // This will be returned with stream completion.
                if let finishReason = openAIResp.choices.first?.finishReason {
                    self.finishReason = finishReason
                }
                
            }

        }


    }
    
    public func onComment(comment: String) {
        print("[OpenAIStreamHandler] Stream received comment: \(comment)" + "\n")

    }
    
    public func onError(error: Error) {
        print("[OpenAIStreamHandler] Stream encountered Error! \(error.localizedDescription)" + "\n")
    }
}

public class OpenAIStreamHandler: StreamEventHandler, ObservableObject {
    
    @Published var streamAccumulator: String = ""
    @Published var streamLatest: String = ""
    
    @Published var streamObject: OpenAI?
    
    public var finishReason: Choice.FinishReason?
        
    public func onOpenAIStreamingGeneration(streamingMessage: OpenAI) {
        //print("Got OpenAI Response Object: \(streamingGenerationResponse.choices.first?.text ?? "N/A")")
        streamObject = streamingMessage
        if let text = streamingMessage.choices.first?.text {
            streamAccumulator += text
            streamLatest = text
        }
        //print(streamAccumulator)
        
        
    }
    
    public func onGenerationStreamCompleted(with finishReason: Choice.FinishReason?) {
        //todo
        print("finished stream with \(finishReason == nil ? "nil/unknown reason" : finishReason!.rawValue) 🏁")
    }
    

    

    
    
    
}
