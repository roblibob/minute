import MinuteCore
import SwiftUI

struct ScreenContextSettingsSection: View {
    let title: String?
    let showsMasterToggle: Bool

    @AppStorage(AppDefaultsKey.screenContextEnabled)
    private var screenContextEnabled: Bool = AppConfiguration.Defaults.defaultScreenContextEnabled
    @AppStorage(AppDefaultsKey.screenContextVideoImportEnabled)
    private var videoImportEnabled: Bool = AppConfiguration.Defaults.defaultScreenContextVideoImportEnabled
    @AppStorage(AppDefaultsKey.screenContextCaptureIntervalSeconds)
    private var captureIntervalSeconds: Double = AppConfiguration.Defaults.defaultScreenContextCaptureIntervalSeconds

    init(title: String? = "Screen Context", showsMasterToggle: Bool = true) {
        self.title = title
        self.showsMasterToggle = showsMasterToggle
    }

    var body: some View {
        Group {
            if let title {
                Section(title) {
                    content
                }
            } else {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if showsMasterToggle {
            SettingsToggleRow(
                "Enhance notes with selected screen context",
                detail: "Choose a window each time you start recording. No video is stored.",
                isOn: $screenContextEnabled
            )
        }

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Capture interval")
                    Spacer()
                    Text(intervalLabel)
                        .minuteCaption()
                }
                SettingsSteppedControl(
                    stepLabels: Self.captureIntervals.map(Self.label(for:)),
                    selectedIndex: captureIntervalIndex
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .gridCellColumns(2)

            SettingsToggleRow(
                "Enhance video imports with frame text",
                detail: "When enabled, video imports are sampled for on-screen text.",
                isOn: $videoImportEnabled
            )
        }
        .disabled(showsMasterToggle && !screenContextEnabled)
        .opacity(!showsMasterToggle || screenContextEnabled ? 1 : 0.55)
    }

    nonisolated private static let captureIntervals: [Double] = [10, 30, 60]

    private var captureIntervalIndex: Binding<Int> {
        Binding<Int>(
            get: {
                Self.index(for: captureIntervalSeconds)
            },
            set: { newValue in
                let index = max(0, min(newValue, Self.captureIntervals.count - 1))
                captureIntervalSeconds = Self.captureIntervals[index]
            }
        )
    }

    private var intervalLabel: String {
        Self.label(for: captureIntervalSeconds)
    }

    nonisolated private static func index(for value: Double) -> Int {
        if let index = captureIntervals.firstIndex(of: value) {
            return index
        }
        let deltas = captureIntervals.map { abs($0 - value) }
        let minDelta = deltas.min() ?? 0
        return deltas.firstIndex(of: minDelta) ?? 0
    }

    nonisolated private static func label(for value: Double) -> String {
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
