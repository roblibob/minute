import AppKit
import SwiftUI

struct SettingsFieldBlock<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .minuteRowTitle()

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .minuteCaption()
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsSingleLineInput: View {
    @Binding var text: String
    let placeholder: String
    var isEditable: Bool = true

    var body: some View {
        Group {
            if isEditable {
                SettingsLeftAlignedTextField(text: $text, placeholder: placeholder)
            } else {
                Text(text.isEmpty ? placeholder : text)
                    .foregroundStyle(text.isEmpty ? Color.minuteTextMuted : Color.minuteTextPrimary)
                    .minuteControlValue()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, MinuteControlMetrics.horizontalPadding)
        .padding(.vertical, MinuteControlMetrics.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .minuteInputFieldChrome()
    }
}

struct SettingsLeftAlignedTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.alignment = .left
        field.baseWritingDirection = .leftToRight
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        field.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.alignment = .left
        nsView.baseWritingDirection = .leftToRight
        nsView.placeholderString = placeholder
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        private var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

struct SettingsMultilineInput: View {
    @Binding var text: String
    let placeholder: String
    let minHeight: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .minuteCaption()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .minuteInputFieldChrome()
    }
}

struct SettingsReadOnlyValue: View {
    let text: String
    let placeholder: String

    init(text: String, placeholder: String = "Not set") {
        self.text = text
        self.placeholder = placeholder
    }

    var body: some View {
        Text(displayValue)
            .foregroundStyle(text.isEmpty ? Color.minuteTextMuted : Color.minuteTextPrimary)
            .minuteControlValue()
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MinuteControlMetrics.horizontalPadding)
            .padding(.vertical, MinuteControlMetrics.verticalPadding)
            .minuteInputFieldChrome()
    }

    private var displayValue: String {
        text.isEmpty ? placeholder : text
    }
}

struct SettingsInlineMessage: View {
    enum Tone {
        case neutral
        case warning
        case error

        var color: Color {
            switch self {
            case .neutral:
                return Color.minuteTextSecondary
            case .warning:
                return .orange
            case .error:
                return .red
            }
        }
    }

    let text: String
    var tone: Tone = .neutral

    var body: some View {
        Text(text)
            .minuteCaption()
            .foregroundStyle(tone.color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsActionRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 10) {
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.minuteSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.minuteOutline, lineWidth: 1)
        )
    }
}

struct SettingsMenuField<Option>: View {
    let title: String
    let subtitle: String?
    let options: [Option]
    let selectionLabel: String
    let optionLabel: (Option) -> String
    let isSelected: (Option) -> Bool
    let onSelect: (Option) -> Void

    var body: some View {
        SettingsFieldBlock(title: title, subtitle: subtitle) {
            Menu {
                ForEach(Array(options.indices), id: \.self) { index in
                    let option = options[index]
                    Button {
                        onSelect(option)
                    } label: {
                        if isSelected(option) {
                            Label(optionLabel(option), systemImage: "checkmark")
                        } else {
                            Text(optionLabel(option))
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selectionLabel)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.minuteTextSecondary)
                }
                .minuteDropdownStyle()
            }
            .menuStyle(.borderlessButton)
        }
    }
}
