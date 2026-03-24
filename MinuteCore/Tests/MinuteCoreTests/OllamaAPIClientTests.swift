import Foundation
import Testing
@testable import MinuteOllama

@Suite(.serialized)
struct OllamaAPIClientTests {
    @Test
    func generate_usesThinkingFallbackWhenResponseIsEmpty() async throws {
        let session = makeClientSession { request in
            #expect(request.url?.path == "/api/generate")
            return .json(
                #"""
                {
                  "model": "qwen3:4b",
                  "response": "",
                  "thinking": "{\n  \"ok\": true\n}",
                  "done": true,
                  "done_reason": "stop"
                }
                """#
            )
        }

        let client = OllamaAPIClient(
            baseURL: URL(string: "http://127.0.0.1:11434")!,
            session: session
        )

        let response = try await client.generate(
            modelTag: "qwen3:4b",
            prompt: "Return JSON.",
            format: "json"
        )

        #expect(response == "{\n  \"ok\": true\n}")
    }

    @Test
    func chat_usesThinkingFallbackWhenContentIsEmpty() async throws {
        let session = makeClientSession { request in
            #expect(request.url?.path == "/api/chat")
            return .json(
                #"""
                {
                  "model": "qwen3:4b",
                  "message": {
                    "role": "assistant",
                    "content": "",
                    "thinking": "Visible answer"
                  },
                  "done": true,
                  "done_reason": "stop"
                }
                """#
            )
        }

        let client = OllamaAPIClient(
            baseURL: URL(string: "http://127.0.0.1:11434")!,
            session: session
        )

        let response = try await client.chat(
            modelTag: "qwen3:4b",
            messages: [.init(role: "user", content: "Hello")]
        )

        #expect(response == "Visible answer")
    }
}

private func makeClientSession(
    handler: @escaping @Sendable (URLRequest) throws -> OllamaClientURLProtocolStub.Response
) -> URLSession {
    OllamaClientURLProtocolStub.handler = handler
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [OllamaClientURLProtocolStub.self]
    return URLSession(configuration: configuration)
}

private final class OllamaClientURLProtocolStub: URLProtocol, @unchecked Sendable {
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
