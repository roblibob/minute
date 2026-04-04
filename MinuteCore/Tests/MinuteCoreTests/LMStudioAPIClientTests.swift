import Foundation
import Testing
@testable import MinuteLMStudio

@Suite(.serialized)
struct LMStudioAPIClientTests {
    @Test
    func complete_usesChatCompletionsAndReturnsMessageContent() async throws {
        let session = makeLMStudioClientSession { request in
            #expect(request.url?.path == "/v1/chat/completions")
            return .json(
                #"""
                {
                  "choices": [
                    {
                      "message": {
                        "content": "{\n  \"ok\": true\n}"
                      }
                    }
                  ]
                }
                """#
            )
        }

        let client = LMStudioAPIClient(
            baseURL: URL(string: "http://127.0.0.1:1234")!,
            session: session
        )

        let response = try await client.complete(
            modelIdentifier: "qwen2.5-7b-instruct",
            systemPrompt: "Return JSON.",
            prompt: "Hello",
            maxTokens: 64
        )

        #expect(response == "{\n  \"ok\": true\n}")
    }

    @Test
    func chat_readsMultipartContentResponses() async throws {
        let session = makeLMStudioClientSession { request in
            #expect(request.url?.path == "/v1/chat/completions")
            return .json(
                #"""
                {
                  "choices": [
                    {
                      "message": {
                        "content": [
                          { "type": "text", "text": "Visible answer" }
                        ]
                      }
                    }
                  ]
                }
                """#
            )
        }

        let client = LMStudioAPIClient(
            baseURL: URL(string: "http://127.0.0.1:1234")!,
            session: session
        )

        let response = try await client.chat(
            modelIdentifier: "qwen2.5-vl-7b",
            messages: [.init(role: "user", content: [.text("Describe this image")])],
            maxTokens: 64
        )

        #expect(response == "Visible answer")
    }
}

private func makeLMStudioClientSession(
    handler: @escaping @Sendable (URLRequest) throws -> LMStudioClientURLProtocolStub.Response
) -> URLSession {
    LMStudioClientURLProtocolStub.handler = handler
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [LMStudioClientURLProtocolStub.self]
    return URLSession(configuration: configuration)
}

private final class LMStudioClientURLProtocolStub: URLProtocol, @unchecked Sendable {
    enum Response {
        case json(String)
        case status(Int, String)
    }

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> Response)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let response = try Self.handler?(request) ?? .status(500, #"{"error":"missing handler"}"#)
            let payload: String
            let statusCode: Int
            switch response {
            case .json(let body):
                payload = body
                statusCode = 200
            case .status(let code, let body):
                payload = body
                statusCode = code
            }

            let httpResponse = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(payload.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
