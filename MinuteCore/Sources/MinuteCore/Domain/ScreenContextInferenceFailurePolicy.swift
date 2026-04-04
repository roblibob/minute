import Foundation

public enum ScreenContextInferenceFailurePolicy {
    public static func terminalMessage(for error: Error) -> String? {
        guard let minuteError = error as? MinuteError else { return nil }

        switch minuteError {
        case .modelMissing:
            return "Screen context is unavailable because the selected vision model files are missing. Repair or reselect the model in Settings -> Models."
        case .mmprojMissing:
            return "Screen context is unavailable because the selected multimodal projector file is missing. Repair or reselect the model in Settings -> Models."
        case .llamaMTMDMissing:
            return "Screen context is unavailable because the multimodal inference component is missing. Repair the local installation and try again."
        case .llamaMTMDFailed(let exitCode, let output):
            return terminalMessageForMTMDFailure(exitCode: exitCode, output: output)
        default:
            return nil
        }
    }
}

private extension ScreenContextInferenceFailurePolicy {
    static func terminalMessageForMTMDFailure(exitCode: Int32, output: String) -> String? {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedOutput = trimmedOutput.lowercased()

        let imageInputFailureMarkers = [
            "number of image token positions",
            "number of image features",
            "could not process image input",
            "image token positions",
            "iterating prediction stream",
            "the model has crashed without additional information"
        ]

        let isLikelyPermanentImageInputFailure =
            exitCode == 400
            || imageInputFailureMarkers.contains { normalizedOutput.contains($0) }

        guard isLikelyPermanentImageInputFailure else { return nil }

        if trimmedOutput.isEmpty {
            return "Selected vision model could not process image input. Choose another vision-capable model in Settings -> Models."
        }

        return """
        Selected vision model could not process image input. Choose another vision-capable model in Settings -> Models. Provider reported: \(trimmedOutput)
        """
    }
}
