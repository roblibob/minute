import Testing
@testable import MinuteCore

struct FluidAudioASRVersionResolverTests {
    @Test
    func resolvesV2Key() {
        #expect(FluidAudioASRVersionResolver.version(for: "v2") == .v2)
    }

    @Test
    func resolvesTdtCtc110mAliases() {
        #expect(FluidAudioASRVersionResolver.version(for: "tdtctc110m") == .tdtCtc110m)
        #expect(FluidAudioASRVersionResolver.version(for: "tdt-ctc-110m") == .tdtCtc110m)
        #expect(FluidAudioASRVersionResolver.version(for: "tdt_ctc_110m") == .tdtCtc110m)
    }

    @Test
    func defaultsUnknownKeysToV3() {
        #expect(FluidAudioASRVersionResolver.version(for: "unknown") == .v3)
    }
}
