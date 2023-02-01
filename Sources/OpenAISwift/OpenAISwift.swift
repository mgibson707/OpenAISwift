import Foundation
#if canImport(FoundationNetworking) && canImport(FoundationXML)
import FoundationNetworking
import FoundationXML
#endif
import Combine
import LDSwiftEventSource

public enum OpenAIError: Error {
    case genericError(error: Error)
    case decodingError(error: Error)
    case noClient
    case streamingError(error: Error?)
    case noAPIKey
}



public class OpenAISwift {
    internal fileprivate(set) var token: String?
    
    private var eventSources = Array<EventSource>()

    public init(authToken: String) {
        self.token = authToken
    }

    public func streamCompletion(with prompt: String, for model: OpenAIModelType = .gpt3(.davinci), maxTokens: Int = 16, stop: [String]? = nil, echo: Bool = false) -> AnyPublisher<OpenAI, Error>? {
        
        // Handler for events recieved on the EventSource stream once started
        let eventStreamHandler: OpenAIStreamHandler = OpenAIStreamHandler()
        
        // Create a configuration struct, initialized with the event handler and generations endpoint URL
        var config = EventSource.Config(handler: eventStreamHandler, url: Endpoint.completions.fullURL())
        
        // add auth header to config if auth token is set
        if let token = token, !token.isEmpty {
            config.headers = ["Authorization": "Bearer \(token)",
                              "Accept": "text/event-stream",
                              "Cache-Control": "no-cache",
                              "Content-Type": "application/json",
                              "Host": "api.openai.com"]
        } else {
            print("[OpenAISwift] Warning: No Auth Key Provided. Please configure your API Key")
            return nil
        }
        // config disable retry on error
        config.connectionErrorHandler = { _ in .shutdown }
        // config HTTP request Method
        config.method = Endpoint.completions.method
    
        // config HTTP request body
        let body = Command(prompt: prompt, model: model.modelName, maxTokens: maxTokens, stream: true, stop: stop, echo: echo)
        guard let bodyData = try? JSONEncoder().encode(body) else {
            print("[OpenAISwift] Warning: Body data could not be encoded to JSON. Cannot create stream.")
            return nil
        }
        config.body = bodyData

        // Create EventSource object for this generation response stream
        let eventSource = EventSource(config: config)
        eventSources.append(eventSource)
        eventSource.start()

        return eventStreamHandler.currentStreamObject.eraseToAnyPublisher()

    }
}

extension OpenAISwift {
    /// Send a Completion to the OpenAI API
    /// - Parameters:
    ///   - prompt: The Text Prompt
    ///   - model: The AI Model to Use. Set to `OpenAIModelType.gpt3(.davinci)` by default which is the most capable model
    ///   - maxTokens: The limit character for the returned response, defaults to 16 as per the API
    ///   - completionHandler: Returns an OpenAI Data Model
    public func sendCompletion(with prompt: String, model: OpenAIModelType = .gpt3(.davinci), maxTokens: Int = 16, stop: [String]? = nil, echo: Bool = false, completionHandler: @escaping (Result<OpenAI, OpenAIError>) -> Void) {
        let endpoint = Endpoint.completions
        let body = Command(prompt: prompt, model: model.modelName, maxTokens: maxTokens, stop: stop, echo: echo)
        let request = prepareRequest(endpoint, body: body)
        
        makeRequest(request: request) { result in
            switch result {
            case .success(let success):
                do {
                    let res = try JSONDecoder().decode(OpenAI.self, from: success)
                    completionHandler(.success(res))
                } catch {
                    completionHandler(.failure(.decodingError(error: error)))
                }
            case .failure(let failure):
                completionHandler(.failure(.genericError(error: failure)))
            }
        }
    }
    
    /// Send a Edit request to the OpenAI API
    /// - Parameters:
    ///   - instruction: The Instruction For Example: "Fix the spelling mistake"
    ///   - model: The Model to use, the only support model is `text-davinci-edit-001`
    ///   - input: The Input For Example "My nam is Adam"
    ///   - completionHandler: Returns an OpenAI Data Model
    public func sendEdits(with instruction: String, model: OpenAIModelType = .feature(.davinci), input: String = "", completionHandler: @escaping (Result<OpenAI, OpenAIError>) -> Void) {
        let endpoint = Endpoint.edits
        let body = Instruction(instruction: instruction, model: model.modelName, input: input)
        let request = prepareRequest(endpoint, body: body)
        
        makeRequest(request: request) { result in
            switch result {
            case .success(let success):
                do {
                    let res = try JSONDecoder().decode(OpenAI.self, from: success)
                    completionHandler(.success(res))
                } catch {
                    completionHandler(.failure(.decodingError(error: error)))
                }
            case .failure(let failure):
                completionHandler(.failure(.genericError(error: failure)))
            }
        }
    }
    
    private func makeRequest(request: URLRequest, completionHandler: @escaping (Result<Data, Error>) -> Void) {
        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completionHandler(.failure(error))
            } else if let data = data {
                completionHandler(.success(data))
            }
        }
        
        task.resume()
    }
    
    private func prepareRequest<BodyType: Encodable>(_ endpoint: Endpoint, body: BodyType) -> URLRequest {
        var urlComponents = URLComponents(url: URL(string: endpoint.baseURL())!, resolvingAgainstBaseURL: true)
        urlComponents?.path = endpoint.path
        var request = URLRequest(url: urlComponents!.url!)
        request.httpMethod = endpoint.method
        
        if let token = self.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(body) {
            request.httpBody = encoded
        }
        
        return request
    }
}

extension OpenAISwift {
    /// Send a Completion to the OpenAI API
    /// - Parameters:
    ///   - prompt: The Text Prompt
    ///   - model: The AI Model to Use. Set to `OpenAIModelType.gpt3(.davinci)` by default which is the most capable model
    ///   - maxTokens: The limit character for the returned response, defaults to 16 as per the API
    /// - Returns: Returns an OpenAI Data Model
    @available(swift 5.5)
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    public func sendCompletion(with prompt: String, model: OpenAIModelType = .gpt3(.davinci), maxTokens: Int = 16, stop: [String]? = nil, echo: Bool = false) async throws -> OpenAI {
        return try await withCheckedThrowingContinuation { continuation in
            sendCompletion(with: prompt, model: model, maxTokens: maxTokens, stop: stop, echo: echo) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// Send a Edit request to the OpenAI API
    /// - Parameters:
    ///   - instruction: The Edit Instruction. For Example: "Fix the spelling mistake"
    ///   - model: The Model to use, the only supported model is `text-davinci-edit-001` represented as `.feature(.davinci)`
    ///   - input: The Input text. For Example "My name is Adam"
    ///   - completionHandler: Returns an OpenAI Data Model
    @available(swift 5.5)
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    public func sendEdits(with instruction: String, model: OpenAIModelType = .feature(.davinci), input: String = "") async throws -> OpenAI {
        return try await withCheckedThrowingContinuation { continuation in
            sendEdits(with: instruction, model: model, input: input) { result in
                continuation.resume(with: result)
            }
        }
    }
}


extension OpenAISwift {
    /// Send a Completion to the OpenAI API
    /// - Parameters:
    ///   - prompt: The Text Prompt
    ///   - model: The AI Model to Use. Set to `OpenAIModelType.gpt3(.davinci)` by default which is the most capable model
    ///   - maxTokens: The limit character for the returned response, defaults to 16 as per the API
    ///   - completionHandler: Returns an OpenAI Data Model
    public func getCompletion(with prompt: String, model: OpenAIModelType = .gpt3(.davinci), maxTokens: Int = 16, stop: [String]? = nil, echo: Bool = false) -> Future<OpenAI, OpenAIError> {
        return Future() { [weak self] promise in
            guard let self = self else {promise(.failure(.noClient)); return}
            let endpoint = Endpoint.completions
            let body = Command(prompt: prompt, model: model.modelName, maxTokens: maxTokens, stop: stop, echo: echo)
            let request = self.prepareRequest(endpoint, body: body)
            
            self.makeRequest(request: request) { result in
                switch result {
                case .success(let success):
                    do {
                        let res = try JSONDecoder().decode(OpenAI.self, from: success)
                        //completionHandler(.success(res))
                        promise(.success(res))
                    } catch {
                        //completionHandler(.failure(.decodingError(error: error)))
                        promise(.failure(.decodingError(error: error)))
                    }
                case .failure(let failure):
                        //completionHandler(.failure(.genericError(error: failure)))
                    promise(.failure(.genericError(error: failure)))
                }
            }
        }

    }
    
    
    
    /// Send a Edit request to the OpenAI API
    /// - Parameters:
    ///   - instruction: The Instruction For Example: "Fix the spelling mistake"
    ///   - model: The Model to use, the only support model is `text-davinci-edit-001`
    ///   - input: The Input For Example "My nam is Adam"
    ///   - completionHandler: Returns an OpenAI Data Model
    public func getEdits(with instruction: String, model: OpenAIModelType = .feature(.davinci), input: String = "") -> Future<OpenAI, OpenAIError> {
        return Future() { [weak self] promise in
            guard let self = self else {promise(.failure(.noClient)); return}

            let endpoint = Endpoint.edits
            let body = Instruction(instruction: instruction, model: model.modelName, input: input)
            let request = self.prepareRequest(endpoint, body: body)
            
            self.makeRequest(request: request) { result in
                switch result {
                case .success(let success):
                    do {
                        let res = try JSONDecoder().decode(OpenAI.self, from: success)
                        promise(.success(res))
                    } catch {
                        promise(.failure(.decodingError(error: error)))
                    }
                case .failure(let failure):
                    promise(.failure(.genericError(error: failure)))
                }
            }
        }

    }
}


extension OpenAISwift {
    
    
    
}
