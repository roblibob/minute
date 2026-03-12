import Testing
import Foundation
@testable import MinuteCore

struct TranscriptionModelCatalogTests {
    @Test
    func all_containsBaseModel() {
        let ids = TranscriptionModelCatalog.all.map(\.id)
        #expect(ids.contains("whisper/base"))
    }

    @Test
    func all_containsNBWhisperModels() {
        let ids = TranscriptionModelCatalog.all.map(\.id)
        #expect(ids.contains("nb-whisper/small"))
        #expect(ids.contains("nb-whisper/medium"))
        #expect(ids.contains("nb-whisper/large"))
    }

    @Test
    func nbWhisperModels_haveUniqueFileNames() {
        let nbModels = TranscriptionModelCatalog.all.filter { $0.id.hasPrefix("nb-whisper/") }
        let fileNames = Set(nbModels.map(\.fileName))
        #expect(fileNames.count == nbModels.count)
    }

    @Test
    func nbWhisperModels_haveExpectedFileSizes() {
        for model in TranscriptionModelCatalog.all where model.id.hasPrefix("nb-whisper/") {
            #expect(model.expectedFileSizeBytes != nil)
            #expect(model.expectedFileSizeBytes! > 0)
        }
    }

    @Test
    func nbWhisperModels_haveHuggingFaceSourceURLs() {
        for model in TranscriptionModelCatalog.all where model.id.hasPrefix("nb-whisper/") {
            #expect(model.sourceURL.host?.contains("huggingface.co") == true)
        }
    }

    @Test
    func nbWhisperModels_doNotHaveCoreMLEncoders() {
        for model in TranscriptionModelCatalog.all where model.id.hasPrefix("nb-whisper/") {
            #expect(model.encoderCoreMLSourceURL == nil)
            #expect(model.encoderCoreMLDestinationURL == nil)
        }
    }

    @Test
    func allModels_haveUniqueIDs() {
        let ids = TranscriptionModelCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test
    func allModels_haveUniqueFileNames() {
        let fileNames = TranscriptionModelCatalog.all.map(\.fileName)
        #expect(Set(fileNames).count == fileNames.count)
    }

    @Test
    func model_looksUpNBWhisperByID() {
        let model = TranscriptionModelCatalog.model(for: "nb-whisper/large")
        #expect(model != nil)
        #expect(model?.displayName == "NB-Whisper Large (Norwegian)")
    }

    @Test
    func defaultModel_isWhisperBase() {
        let model = TranscriptionModelCatalog.defaultModel
        #expect(model.id == "whisper/base")
    }
}
