import Foundation
@testable import MinuteCore

enum ClassifierTestHelpers {
    static func parse(_ response: String) -> MeetingType {
        MeetingTypeClassifier.parseResponse(response)
    }
}
