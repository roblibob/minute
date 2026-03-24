import AppKit
import SwiftUI

struct SettingsFieldBlock<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .minuteRowTitle()

            Text(subtitle)
                .minuteCaption()
                .fixedSize(horizontal: false, vertical: true)

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
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.minuteOutline, lineWidth: 1)
        )
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
