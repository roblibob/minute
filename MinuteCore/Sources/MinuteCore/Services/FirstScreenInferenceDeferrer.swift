import Foundation

public actor FirstScreenInferenceDeferrer {
    private let processingBusyGate: ProcessingBusyGate
    private var hasAttemptedFirstInference = false
    private var deferred = false

    public init(processingBusyGate: ProcessingBusyGate) {
        self.processingBusyGate = processingBusyGate
    }

    public var isDeferred: Bool {
        deferred
    }

    /// Returns true if the first inference attempt may start now.
    ///
    /// v1 behavior:
    /// - If meeting processing is currently busy, defer the first attempt.
    /// - Once the first attempt has been allowed, subsequent attempts are never deferred.
    public func shouldStartFirstInferenceAttemptNow() async -> Bool {
        if hasAttemptedFirstInference {
            deferred = false
            return true
        }

        if await processingBusyGate.isBusy {
            deferred = true
            return false
        }

        deferred = false
        hasAttemptedFirstInference = true
        return true
    }
}
