import Foundation
import Testing
@testable import MinuteCore
@testable import MinuteOllama

@Suite(.serialized)
struct OllamaModelDiscoveryServiceTests {
    @Test
    func discoverModels_readsLocalInventoryAndVisionCapabilities() async throws {
        let showResponses = LockedShowResponseQueue(
            responses: [
                .json(
                    #"""
                    {
                      "capabilities": ["completion"],
                      "details": {
                        "parameter_size": "4B",
                        "quantization_level": "Q4_K_M"
                      },
                      "model_info": {
                        "general.families": ["phi4"],
                        "llama.context_length": 8192
                      }
                    }
                    """#
                ),
                .json(
                    #"""
                    {
                      "capabilities": ["completion", "vision"],
                      "details": {
                        "parameter_size": "7B",
                        "quantization_level": "Q4_K_M"
                      },
                      "model_info": {
                        "general.families": ["llava"],
                        "llama.context_length": 8192
                      }
                    }
                    """#
                ),
            ]
        )
        let session = makeSession { request in
            switch request.url?.path {
            case "/api/version":
                return .json(#"{ "version": "0.6.1" }"#)
            case "/api/tags":
                return .json(
                    #"""
                    {
                      "models": [
                        {
                          "name": "phi4-mini:latest",
                          "modified_at": "2026-03-24T08:00:00Z",
                          "size": 1234,
                          "digest": "sha256:phi4"
                        },
                        {
                          "name": "llava:latest",
                          "modified_at": "2026-03-24T09:00:00Z",
                          "size": 5678,
                          "digest": "sha256:llava"
                        }
                      ]
                    }
                    """#
                )
            case "/api/show":
                return showResponses.next()
            default:
                Issue.record("Unexpected request: \(String(describing: request.url))")
                return .status(404, #"{"error":"not found"}"#)
            }
        }

        let service = OllamaModelDiscoveryService(
            client: OllamaAPIClient(
                baseURL: URL(string: "http://127.0.0.1:11434")!,
                session: session
            )
        )

        let snapshot = try await service.discoverModels()

        #expect(snapshot.daemonReachable)
        #expect(snapshot.daemonVersion == "0.6.1")
        #expect(snapshot.models.count == 2)
        #expect(snapshot.models.first(where: { $0.tag == "phi4-mini:latest" })?.supportsVision == false)
        #expect(snapshot.models.first(where: { $0.tag == "llava:latest" })?.supportsVision == true)
    }

    @Test
    func discoverModels_whenDaemonUnavailable_returnsUnavailableSnapshot() async throws {
        let session = makeSession { _ in
            throw URLError(.cannotConnectToHost)
        }
        let service = OllamaModelDiscoveryService(
            client: OllamaAPIClient(
                baseURL: URL(string: "http://127.0.0.1:11434")!,
                session: session
            )
        )

        let snapshot = try await service.discoverModels()

        #expect(snapshot.daemonReachable == false)
        #expect(snapshot.models.isEmpty)
        #expect(snapshot.failureReason != nil)
    }

    @Test
    func validateModelTag_rejectsVisionCapabilityWhenModelLacksVisionSupport() async throws {
        let session = makeSession { request in
            switch request.url?.path {
            case "/api/show":
                return .json(
                    #"""
                    {
                      "capabilities": ["completion"],
                      "details": {
                        "parameter_size": "4B",
                        "quantization_level": "Q4_K_M"
                      },
                      "model_info": {
                        "general.families": ["phi4"],
                        "llama.context_length": 8192
                      }
                    }
                    """#
                )
            default:
                return .json(#"{ "version": "0.6.1" }"#)
            }
        }
        let service = OllamaModelDiscoveryService(
            client: OllamaAPIClient(
                baseURL: URL(string: "http://127.0.0.1:11434")!,
                session: session
            )
        )

        let state = try await service.validateModelTag("phi4-mini:latest", for: .vision)

        #expect(state.status == .visionUnsupported)
        #expect(state.isReady == false)
    }

    @Test
    func validateModelTag_reportsMissingModel() async throws {
        let session = makeSession { request in
            switch request.url?.path {
            case "/api/show":
                return .status(404, #"{"error":"model not found"}"#)
            default:
                return .json(#"{ "version": "0.6.1" }"#)
            }
        }
        let service = OllamaModelDiscoveryService(
            client: OllamaAPIClient(
                baseURL: URL(string: "http://127.0.0.1:11434")!,
                session: session
            )
        )

        let state = try await service.validateModelTag("missing:latest", for: .summarization)

        #expect(state.status == .modelMissing)
        #expect(state.selectedReference == "missing:latest")
    }
}

private func makeSession(
    handler: @escaping @Sendable (URLRequest) throws -> URLProtocolStub.Response
) -> URLSession {
    URLProtocolStub.handler = handler
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    return URLSession(configuration: configuration)
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
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

private final class LockedShowResponseQueue: @unchecked Sendable {
    private var responses: [URLProtocolStub.Response]
    private let lock = NSLock()

    init(responses: [URLProtocolStub.Response]) {
        self.responses = responses
    }

    func next() -> URLProtocolStub.Response {
        lock.lock()
        defer { lock.unlock() }
        guard !responses.isEmpty else {
            return .status(500, #"{"error":"missing queued response"}"#)
        }
        return responses.removeFirst()
    }
}
