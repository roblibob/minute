import Foundation
import Testing
@testable import MinuteCore

struct ProcessingBusyGateTests {
    actor Flag {
        private var value = false

        func setTrue() {
            value = true
        }

        func get() -> Bool {
            value
        }
    }

    @Test
    func isBusy_isFalseInitially() async {
        let gate = ProcessingBusyGate()
        #expect(await gate.isBusy == false)
    }

    @Test
    func isBusy_isTrueWhileTokenHeld() async {
        let gate = ProcessingBusyGate()
        #expect(await gate.isBusy == false)

        let token = await gate.beginBusyScope()
        #expect(await gate.isBusy == true)

        await token.end()
        #expect(await gate.isBusy == false)
    }

    @Test
    func waitUntilIdle_blocksUntilBusyScopeEnds() async throws {
        let gate = ProcessingBusyGate()
        let token = await gate.beginBusyScope()

        let flag = Flag()
        let waiter = Task {
            await gate.waitUntilIdle()
            await flag.setTrue()
        }

        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(await flag.get() == false)

        await token.end()
        _ = await waiter.value
        #expect(await flag.get() == true)
    }
}
