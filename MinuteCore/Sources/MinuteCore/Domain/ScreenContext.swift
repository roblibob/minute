import Foundation

public struct ScreenContextSnapshot: Sendable, Equatable {
    public var capturedAt: Date
    public var windowTitle: String
    public var extractedLines: [String]

    public init(capturedAt: Date, windowTitle: String, extractedLines: [String]) {
        self.capturedAt = capturedAt
        self.windowTitle = windowTitle
        self.extractedLines = extractedLines
    }
}

public struct ScreenContextSummary: Sendable, Equatable {
    public var agendaItems: [String]
    public var participantCount: Int?
    public var participantNames: [String]
    public var sharedArtifacts: [String]
    public var keyHeadings: [String]
    public var notes: [String]

    public init(
        agendaItems: [String] = [],
        participantCount: Int? = nil,
        participantNames: [String] = [],
        sharedArtifacts: [String] = [],
        keyHeadings: [String] = [],
        notes: [String] = []
    ) {
        self.agendaItems = agendaItems
        self.participantCount = participantCount
        self.participantNames = participantNames
        self.sharedArtifacts = sharedArtifacts
        self.keyHeadings = keyHeadings
        self.notes = notes
    }

    public var isEmpty: Bool {
        agendaItems.isEmpty &&
        participantCount == nil &&
        participantNames.isEmpty &&
        sharedArtifacts.isEmpty &&
        keyHeadings.isEmpty &&
        notes.isEmpty
    }

    public func promptAppendix(maxItems: Int = 6) -> String? {
        guard !isEmpty else { return nil }

        var lines: [String] = []
        lines.append("Screen context (from selected windows; may be incomplete):")

        if let participantCount {
            if participantNames.isEmpty {
                lines.append("- Participants: \(participantCount)")
            } else {
                let names = participantNames.prefix(maxItems).joined(separator: ", ")
                lines.append("- Participants: \(participantCount) (\(names))")
            }
        } else if !participantNames.isEmpty {
            let names = participantNames.prefix(maxItems).joined(separator: ", ")
            lines.append("- Participants: \(names)")
        }

        if !agendaItems.isEmpty {
            let agenda = agendaItems.prefix(maxItems).joined(separator: "; ")
            lines.append("- Agenda: \(agenda)")
        }

        if !sharedArtifacts.isEmpty {
            let artifacts = sharedArtifacts.prefix(maxItems).joined(separator: "; ")
            lines.append("- Shared artifacts: \(artifacts)")
        }

        if !keyHeadings.isEmpty {
            let headings = keyHeadings.prefix(maxItems).joined(separator: "; ")
            lines.append("- Headings: \(headings)")
        }

        if !notes.isEmpty {
            let extras = notes.prefix(maxItems).joined(separator: "; ")
            lines.append("- Notes: \(extras)")
        }

        return lines.joined(separator: "\n")
    }
}

public struct ScreenContextWindowSelection: Sendable, Equatable, Codable {
    public var bundleIdentifier: String
    public var applicationName: String
    public var windowTitle: String

    public init(bundleIdentifier: String, applicationName: String, windowTitle: String) {
        self.bundleIdentifier = bundleIdentifier
        self.applicationName = applicationName
        self.windowTitle = windowTitle
    }
}
