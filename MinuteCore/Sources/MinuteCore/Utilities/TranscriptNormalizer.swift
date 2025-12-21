import Foundation

public enum TranscriptNormalizer {
    /// Normalizes whisper.cpp CLI output into a transcript suitable for prompting.
    ///
    /// This is intentionally conservative and deterministic:
    /// - Strips ANSI escape codes
    /// - Filters common progress / timing / diagnostic lines
    /// - Trims whitespace
    /// - Collapses excessive blank lines
    public static func normalizeWhisperOutput(_ output: String) -> String {
        let withoutANSI = stripANSISequences(output)
        let lines = withoutANSI
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var kept: [String] = []
        kept.reserveCapacity(lines.count)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Filter empty lines later (we collapse), but keep placeholders for now.
            if trimmed.isEmpty {
                kept.append("")
                continue
            }

            if isWhisperNoiseLine(trimmed) {
                continue
            }

            kept.append(trimmed)
        }

        // Collapse excessive blank lines.
        var collapsed: [String] = []
        collapsed.reserveCapacity(kept.count)

        var previousWasBlank = false
        for line in kept {
            let isBlank = line.isEmpty
            if isBlank {
                if previousWasBlank {
                    continue
                }
                previousWasBlank = true
            } else {
                previousWasBlank = false
            }
            collapsed.append(line)
        }

        let normalized = collapsed
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized
    }

    private static func isWhisperNoiseLine(_ line: String) -> Bool {
        // Common whisper.cpp progress line: "[ 12%]" or similar.
        if line.range(of: "^\\[\\s*\\d+%\\s*\\]", options: .regularExpression) != nil {
            return true
        }

        // Timing summary / diagnostics often end up on stdout/stderr.
        if line.hasPrefix("whisper_print_timings") { return true }
        if line.hasPrefix("system_info") { return true }
        if line.hasPrefix("main:") { return true }
        if line.hasPrefix("ggml_") { return true }
        if line.hasPrefix("whisper_") { return true }

        return false
    }

    private static func stripANSISequences(_ input: String) -> String {
        // Removes sequences like "\u{001B}[...m".
        // Use the actual ESC character rather than a "\\u{...}" escape in the regex.
        let esc = "\u{001B}"
        let pattern = esc + "\\[[0-9;]*[A-Za-z]"

        return input.replacingOccurrences(
            of: pattern,
            with: "",
            options: .regularExpression
        )
    }
}
