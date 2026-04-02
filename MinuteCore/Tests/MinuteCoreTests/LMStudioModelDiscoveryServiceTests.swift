import Foundation
import Testing
@testable import MinuteCore
@testable import MinuteLMStudio

@Suite(.serialized)
struct LMStudioModelDiscoveryServiceTests {
    @Test
    func discoverModels_readsLocalInventoryAndVisionCapabilities() async throws {
        let session = makeLMStudioDiscoverySession { request in
            switch request.url?.path {
            case "/api/v0/models":
                return .json(
                    #"""
                    {
                      "data": [
                        {
                          "id": "qwen2.5-vl-7b-instruct",
                          "object": "model",
                          "type": "vlm",
                          "publisher": "lmstudio-community",
                          "arch": "qwen2_vl",
                          "compatibility_type": "gguf",
                          "quantization": "Q4_K_M",
                          "state": "not-loaded",
                          "max_context_length": 32768
                        },
                        {
                          "id": "qwen2.5-7b-instruct",
                          "object": "model",
                          "type": "llm",
                          "publisher": "lmstudio-community",
                          "arch": "qwen2",
                          "compatibility_type": "gguf",
                          "quantization": "Q4_K_M",
                          "state": "loaded",
                          "max_context_length": 131072
                        }
                      ]
                    }
                    """#
                )
            default:
                Issue.record("Unexpected request: \(String(describing: request.url))")
                return .status(404, #"{"error":"not found"}"#)
            }
        }

        let service = LMStudioModelDiscoveryService(
            client: LMStudioAPIClient(
                baseURL: URL(string: "http://127.0.0.1:1234")!,
                session: session
            )
        )

        let snapshot = try await service.discoverModels()

        #expect(snapshot.serverReachable)
        #expect(snapshot.models.count == 2)
        #expect(snapshot.models.first(where: { $0.identifier == "qwen2.5-7b-instruct" })?.supportsVision == false)
        #expect(snapshot.models.first(where: { $0.identifier == "qwen2.5-vl-7b-instruct" })?.supportsVision == true)
    }

    @Test
    func discoverModels_whenServerUnavailable_returnsUnavailableSnapshot() async throws {
        let session = makeLMStudioDiscoverySession { _ in
            throw URLError(.cannotConnectToHost)
        }
        let service = LMStudioModelDiscoveryService(
            client: LMStudioAPIClient(
                baseURL: URL(string: "http://127.0.0.1:1234")!,
                session: session
            )
        )

        let snapshot = try await service.discoverModels()

        #expect(snapshot.serverReachable == false)
        #expect(snapshot.models.isEmpty)
        #expect(snapshot.failureReason != nil)
    }

    @Test
    func validateModelIdentifier_rejectsVisionCapabilityWhenModelLacksVisionSupport() async throws {
        let session = makeLMStudioDiscoverySession { request in
            switch request.url?.path {
            case "/api/v0/models/qwen2.5-7b-instruct":
                return .json(
                    #"""
                    {
                      "id": "qwen2.5-7b-instruct",
                      "object": "model",
                      "type": "llm",
                      "publisher": "lmstudio-community",
                      "arch": "qwen2",
                      "compatibility_type": "gguf",
                      "quantization": "Q4_K_M",
                      "state": "loaded",
                      "max_context_length": 131072
                    }
                    """#
                )
            default:
                return .status(404, #"{"error":"not found"}"#)
            }
        }

        let service = LMStudioModelDiscoveryService(
            client: LMStudioAPIClient(
                baseURL: URL(string: "http://127.0.0.1:1234")!,
                session: session
            )
        )

        let state = try await service.validateModelIdentifier("qwen2.5-7b-instruct", for: .vision)

        #expect(state.status == .visionUnsupported)
        #expect(state.isReady == false)
    }

    @Test
    func validateModelIdentifier_reportsMissingModel() async throws {
        let session = makeLMStudioDiscoverySession { _ in
            return .status(404, #"{"error":"model not found"}"#)
        }

        let service = LMStudioModelDiscoveryService(
            client: LMStudioAPIClient(
                baseURL: URL(string: "http://127.0.0.1:1234")!,
                session: session
            )
        )

        let state = try await service.validateModelIdentifier("missing-model", for: .summarization)

        #expect(state.status == .modelMissing)
        #expect(state.selectedReference == "missing-model")
    }
}

private func makeLMStudioDiscoverySession(
    handler: @escaping @Sendable (URLRequest) throws -> LMStudioDiscoveryURLProtocolStub.Response
) -> URLSession {
    LMStudioDiscoveryURLProtocolStub.handler = handler
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [LMStudioDiscoveryURLProtocolStub.self]
    return URLSession(configuration: configuration)
}

private final class LMStudioDiscoveryURLProtocolStub: URLProtocol, @unchecked Sendable {
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
