import Foundation

public actor ProcessingBusyGate {
    private var busyCount: Int = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    public var isBusy: Bool {
        busyCount > 0
    }

    public func beginBusyScope() -> BusyScopeToken {
        busyCount += 1
        return BusyScopeToken(gate: self)
    }

    public func waitUntilIdle() async {
        if busyCount == 0 {
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    fileprivate func endBusyScope() {
        busyCount = max(0, busyCount - 1)
        if busyCount == 0, !waiters.isEmpty {
            let toResume = waiters
            waiters.removeAll()
            toResume.forEach { $0.resume() }
        }
    }
}

public actor BusyScopeToken: Sendable {
    private let gate: ProcessingBusyGate
    private var hasEnded = false

    fileprivate init(gate: ProcessingBusyGate) {
        self.gate = gate
    }

    public func end() async {
        guard !hasEnded else { return }
        hasEnded = true
        await gate.endBusyScope()
    }
}
