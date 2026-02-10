import Testing
import Foundation
@testable import MinuteCore

struct MinuteCoreTests {
    @Test
    func smoke() {
        #expect(Bool(true))
    }

    @Test
    func meetingPipelineAction_decodesCancelRecording() throws {
        let json = #"{"type":"cancelRecording"}"#
        let decoded = try JSONDecoder().decode(MeetingPipelineAction.self, from: Data(json.utf8))
        #expect(decoded == .cancelRecording)
    }

    @Test
    func meetingPipelineAction_roundTripsImportFile() throws {
        let action = MeetingPipelineAction.importFile(URL(fileURLWithPath: "/tmp/audio.wav"))
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MeetingPipelineAction.self, from: encoded)
        #expect(decoded == action)
    }
}
