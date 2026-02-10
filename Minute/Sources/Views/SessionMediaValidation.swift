import Foundation
import UniformTypeIdentifiers

enum SessionMediaValidation {
    static func isSupportedMediaURL(_ url: URL) -> Bool {
        let ext = normalizedFilenameExtension(from: url)
        if ext == "wav" || ext == "wave" {
            return true
        }
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else { return false }
        return type.conforms(to: .audio) || type.conforms(to: .movie)
    }

    private static func normalizedFilenameExtension(from url: URL) -> String {
        let rawExt: String
        if !url.pathExtension.isEmpty {
            rawExt = url.pathExtension
        } else {
            rawExt = filenameExtension(fromLastPathComponent: url.lastPathComponent) ?? ""
        }

        let decoded = rawExt.removingPercentEncoding ?? rawExt
        return decoded.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func filenameExtension(fromLastPathComponent name: String) -> String? {
        guard let lastDotIndex = name.lastIndex(of: ".") else { return nil }
        let afterDotIndex = name.index(after: lastDotIndex)
        return String(name[afterDotIndex...])
    }

    static var importableContentTypes: [UTType] {
        var types: [UTType] = [.audio, .movie]
        if let wav = UTType(filenameExtension: "wav") {
            types.append(wav)
        }
        return types
    }
}
