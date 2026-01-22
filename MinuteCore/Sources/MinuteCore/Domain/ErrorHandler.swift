import Foundation

public enum ErrorHandler {
    public static func userMessage(for error: Error, fallback: String) -> String {
        if let minuteError = error as? MinuteError {
            return minuteError.errorDescription ?? fallback
        }
        return fallback
    }

    public static func debugMessage(for error: Error) -> String {
        if let minuteError = error as? MinuteError {
            return minuteError.debugSummary
        }
        return String(describing: error)
    }

    public static func minuteError(for error: Error, fallback: MinuteError) -> MinuteError {
        (error as? MinuteError) ?? fallback
    }
}
