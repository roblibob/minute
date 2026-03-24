import AppKit
import MinuteCore
import SwiftUI

struct MeetingTypesSettingsSection: View {
    @ObservedObject var model: MeetingTypesSettingsViewModel

    @State private var isAdvancedPromptExpanded = false
    @State private var isAdvancedClassifierExpanded = false
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField: Hashable {
        case displayName
        case classifierLabel
    }

    var body: some View {
        Group {
            SettingsFieldBlock(
                title: "Selected Meeting Type",
                subtitle: "Built-in types can be overridden. Custom types can be fully edited and deleted."
            ) {
                MeetingTypeSelectionWrapLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(model.meetingTypes, id: \.typeId) { definition in
                        MeetingTypeSelectionChip(
                            title: definition.displayName,
                            symbolName: MeetingTypeSelectionStyle.symbolName(for: definition),
                            symbolTint: MeetingTypeSelectionStyle.symbolTint(for: definition),
                            isSelected: model.selectedTypeID == definition.typeId
                        ) {
                            model.selectType(typeID: definition.typeId)
                        }
                    }

                    Button {
                        model.startCreateCustomType()
                        focusedField = .displayName
                    } label: {
                        Label("Create new...", systemImage: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.minuteGlow)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)
                    .disabled(model.isCreatingCustomType)
                    .opacity(model.isCreatingCustomType ? 0.55 : 1)
                    .accessibilityLabel(Text("Create new meeting type"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Selected meeting type"))
                .accessibilityValue(Text(model.selectedDefinition?.displayName ?? "None"))
            }

            if model.isCreatingCustomType {
                Button("Discard Draft", role: .cancel) {
                    model.cancelCreateCustomType()
                }
            }

            Section(model.isCreatingCustomType ? "New Meeting Type" : "Prompt Content") {
                SettingsFieldBlock(
                    title: "Display Name",
                    subtitle: model.isEditingBuiltIn
                        ? "Built-in names are fixed. Prompt content remains editable."
                        : "Name shown in Settings and the stage picker."
                ) {
                    SettingsSingleLineInput(
                        text: $model.draftDisplayName,
                        placeholder: "Customer Discovery",
                        isEditable: !model.isEditingBuiltIn
                    )
                    .focused($focusedField, equals: .displayName)
                }

                SettingsFieldBlock(
                    title: "Objective",
                    subtitle: "What should this meeting summary optimize for?"
                ) {
                    MultilineInput(
                        text: $model.draftObjective,
                        placeholder: "Summarize daily standup progress accurately.",
                        minHeight: 84
                    )
                }

                SettingsFieldBlock(
                    title: "Summary Focus",
                    subtitle: "Which outcomes should be prioritized in this type of meeting?"
                ) {
                    MultilineInput(
                        text: $model.draftSummaryFocus,
                        placeholder: "Highlight updates, blockers, decisions, and owners.",
                        minHeight: 96
                    )
                }

                DisclosureGroup(isExpanded: $isAdvancedPromptExpanded) {
                    VStack(alignment: .leading, spacing: 16) {
                        PromptRuleBlock(
                            title: "Decision Rules",
                            subtitle: "How to identify and phrase decisions.",
                            text: $model.draftDecisionRules,
                            isEnabled: $model.draftDecisionRulesEnabled,
                            isToggleable: true
                        )

                        PromptRuleBlock(
                            title: "Action Item Rules",
                            subtitle: "How to detect commitments and owners.",
                            text: $model.draftActionItemRules,
                            isEnabled: $model.draftActionItemRulesEnabled,
                            isToggleable: true
                        )

                        PromptRuleBlock(
                            title: "Open Question Rules",
                            subtitle: "How to capture unresolved issues.",
                            text: $model.draftOpenQuestionRules,
                            isEnabled: $model.draftOpenQuestionRulesEnabled,
                            isToggleable: true
                        )

                        PromptRuleBlock(
                            title: "Key Point Rules",
                            subtitle: "What context should always be retained.",
                            text: $model.draftKeyPointRules,
                            isEnabled: $model.draftKeyPointRulesEnabled,
                            isToggleable: true
                        )

                        PromptRuleBlock(
                            title: "Noise Filter Rules",
                            subtitle: "What should be ignored as non-substantive.",
                            text: $model.draftNoiseFilterRules,
                            isEnabled: .constant(true),
                            isToggleable: false
                        )

                        PromptRuleBlock(
                            title: "Additional Guidance",
                            subtitle: "Extra authoring guidance applied to this type.",
                            text: $model.draftAdditionalGuidance,
                            isEnabled: .constant(true),
                            isToggleable: false
                        )
                    }
                    .padding(.top, 8)
                } label: {
                    Button {
                        isAdvancedPromptExpanded.toggle()
                    } label: {
                        HStack {
                            Text("Advanced Prompt Rules")
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if model.isCreatingCustomType || model.isEditingCustomType {
                Section("Classifier") {
                    SettingsToggleRow(
                        "Include this type in autodetect",
                        detail: "When enabled, this type can be selected by automatic classifier routing.",
                        isOn: $model.draftAutodetectEligible
                    )

                    if model.draftAutodetectEligible {
                        SettingsFieldBlock(
                            title: "Classifier Label",
                            subtitle: "Canonical label used for classifier output matching."
                        ) {
                            SettingsSingleLineInput(
                                text: $model.draftClassifierLabel,
                                placeholder: "e.g. Standup"
                            )
                            .focused($focusedField, equals: .classifierLabel)
                        }

                        SettingsFieldBlock(
                            title: "Strong Signals",
                            subtitle: "Comma or newline separated cues. \(model.parsedClassifierSignalCount) signal(s)."
                        ) {
                            MultilineInput(
                                text: $model.draftClassifierSignalsInput,
                                placeholder: "daily update, blocker, sprint board",
                                minHeight: 80
                            )
                        }

                        DisclosureGroup(isExpanded: $isAdvancedClassifierExpanded) {
                            VStack(alignment: .leading, spacing: 16) {
                                PromptRuleBlock(
                                    title: "Counter Signals",
                                    subtitle: "Cues that should reduce this type's likelihood.",
                                    text: $model.draftClassifierCounterSignalsInput,
                                    isEnabled: .constant(true),
                                    isToggleable: false
                                )

                                PromptRuleBlock(
                                    title: "Positive Examples",
                                    subtitle: "Examples likely to belong to this type.",
                                    text: $model.draftClassifierPositiveExamplesInput,
                                    isEnabled: .constant(true),
                                    isToggleable: false
                                )

                                PromptRuleBlock(
                                    title: "Negative Examples",
                                    subtitle: "Examples that should map to other types.",
                                    text: $model.draftClassifierNegativeExamplesInput,
                                    isEnabled: .constant(true),
                                    isToggleable: false
                                )
                            }
                            .padding(.top, 8)
                        } label: {
                            Button {
                                isAdvancedClassifierExpanded.toggle()
                            } label: {
                                HStack {
                                    Text("Advanced Classifier Signals")
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section("Actions") {
                HStack(spacing: 10) {
                    Button(saveButtonTitle) {
                        model.saveDraft()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canSaveDraft)

                    if model.isCreatingCustomType {
                        Button("Cancel") {
                            model.cancelCreateCustomType()
                        }
                    }
                }

                if model.canRestoreSelectedBuiltInDefault && !model.isCreatingCustomType {
                    Button("Restore Built-in Default") {
                        model.restoreBuiltInDefault()
                    }
                }

                if model.canDeleteSelectedCustomType && !model.isCreatingCustomType {
                    Button("Delete Custom Meeting Type", role: .destructive) {
                        model.requestDeleteSelectedCustomType()
                    }
                }

                if model.hasUnsavedChanges {
                    Label("Unsaved changes", systemImage: "pencil")
                        .minuteFootnote()
                }

                if let message = model.errorMessage, !message.isEmpty {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
        }
        .alert(
            "Delete Custom Meeting Type?",
            isPresented: deleteAlertBinding
        ) {
            Button("Delete", role: .destructive) {
                model.confirmDeleteSelectedCustomType()
            }
            Button("Cancel", role: .cancel) {
                model.cancelDeleteConfirmation()
            }
        } message: {
            Text("This removes the type from future selections. Existing processed notes are unchanged.")
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { model.isDeleteConfirmationPresented },
            set: { newValue in
                if !newValue {
                    model.cancelDeleteConfirmation()
                }
            }
        )
    }

    private var saveButtonTitle: String {
        if model.isCreatingCustomType {
            return "Create Meeting Type"
        }
        guard let selected = model.selectedDefinition else { return "Save Changes" }
        return selected.source == .builtIn ? "Save Override" : "Save Changes"
    }

}

private struct PromptRuleBlock: View {
    let title: String
    let subtitle: String
    @Binding var text: String
    @Binding var isEnabled: Bool
    let isToggleable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .minuteRowTitle()

                    Text(subtitle)
                        .minuteCaption()
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if isToggleable {
                    Toggle("", isOn: $isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityLabel(Text("\(title) enabled"))
                }
            }

            if !isToggleable || isEnabled {
                MultilineInput(
                    text: $text,
                    placeholder: "Optional",
                    minHeight: 74
                )
            }
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

private struct MultilineInput: View {
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
