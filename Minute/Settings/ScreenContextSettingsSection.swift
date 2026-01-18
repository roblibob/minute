import MinuteCore
import ScreenCaptureKit
import SwiftUI

struct ScreenContextSettingsSection: View {
    @AppStorage(AppDefaultsKey.screenContextEnabled) private var screenContextEnabled: Bool = false
    @AppStorage(AppDefaultsKey.screenContextVideoImportEnabled) private var videoImportEnabled: Bool = false
    @AppStorage(AppDefaultsKey.screenContextCaptureIntervalSeconds) private var captureIntervalSeconds: Double = 60

    var body: some View {
        Section("Screen Context") {
            Toggle("Enhance notes with selected screen content", isOn: $screenContextEnabled)
                .toggleStyle(.switch)
                .tint(.accentColor)

            Text("Choose a window each time you start recording. No video is stored.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Capture interval")
                    Spacer()
                    Text(intervalLabel)
                        .foregroundStyle(.secondary)
                }

                Slider(value: captureIntervalIndex, in: 0...Double(Self.captureIntervals.count - 1), step: 1)
                    .tint(.accentColor)

                HStack {
                    ForEach(Self.captureIntervals.indices, id: \.self) { index in
                        let value = Self.captureIntervals[index]
                        Text(Self.label(for: value))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if index < Self.captureIntervals.count - 1 {
                            Spacer()
                        }
                    }
                }
            }

            Toggle("Enhance video imports with frame text", isOn: $videoImportEnabled)
                .toggleStyle(.switch)
                .tint(.accentColor)

            Text("When enabled, video imports are sampled for on-screen text.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
