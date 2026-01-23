import MinuteCore
import SwiftUI

struct ScreenContextSettingsSection: View {
    @AppStorage(AppDefaultsKey.screenContextEnabled)
    private var screenContextEnabled: Bool = AppConfiguration.Defaults.defaultScreenContextEnabled
    @AppStorage(AppDefaultsKey.screenContextVideoImportEnabled)
    private var videoImportEnabled: Bool = AppConfiguration.Defaults.defaultScreenContextVideoImportEnabled
    @AppStorage(AppDefaultsKey.screenContextCaptureIntervalSeconds)
    private var captureIntervalSeconds: Double = AppConfiguration.Defaults.defaultScreenContextCaptureIntervalSeconds

    var body: some View {
        Section("Screen Context") {
            SettingsToggleRow(
                "Enhance notes with selected screen content",
                detail: "Choose a window each time you start recording. No video is stored.",
                isOn: $screenContextEnabled
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Capture interval")
                    Spacer()
                    Text(intervalLabel)
                        .minuteCaption()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Slider(value: captureIntervalIndex, in: 0...Double(Self.captureIntervals.count - 1), step: 1)
                        .tint(.accentColor)
                        .frame(maxWidth: .infinity)

                    HStack {
                        ForEach(Self.captureIntervals.indices, id: \.self) { index in
                            let value = Self.captureIntervals[index]
                            Text(Self.label(for: value))
                                .minuteCaption()
                            if index < Self.captureIntervals.count - 1 {
                                Spacer()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SettingsToggleRow(
                "Enhance video imports with frame text",
                detail: "When enabled, video imports are sampled for on-screen text.",
                isOn: $videoImportEnabled
            )
        }
    }

    private static let captureIntervals: [Double] = [10, 30, 60]

    private var captureIntervalIndex: Binding<Double> {
        Binding<Double>(
            get: {
                Double(Self.index(for: captureIntervalSeconds))
            },
            set: { newValue in
                let index = max(0, min(Int(newValue.rounded()), Self.captureIntervals.count - 1))
                captureIntervalSeconds = Self.captureIntervals[index]
            }
        )
    }

    private var intervalLabel: String {
        Self.label(for: captureIntervalSeconds)
    }

    private static func index(for value: Double) -> Int {
        if let index = captureIntervals.firstIndex(of: value) {
            return index
        }
        let deltas = captureIntervals.map { abs($0 - value) }
        let minDelta = deltas.min() ?? 0
        return deltas.firstIndex(of: minDelta) ?? 0
    }

    private static func label(for value: Double) -> String {
        if value >= 60 {
            return "1 min"
        }
        return "\(Int(value)) sec"
    }
}

#Preview {
    Form {
        ScreenContextSettingsSection()
    }
    .frame(width: 480)
}
