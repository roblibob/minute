import AppKit
import SwiftUI

enum RecordButtonState {
    case ready
    case recording
}

struct FloatingControlBar: View {
    let recordState: RecordButtonState
    let recordEnabled: Bool
    let recordingStartedAt: Date?
    let showsCancel: Bool
    let recordFocus: FocusState<Bool>.Binding
    let onRecordTap: () -> Void
    let onCancelTap: () -> Void

    var body: some View {
        ZStack {
            HStack(spacing: 16) {
                Spacer(minLength: 0)

                if showsCancel {
                    Button(action: onCancelTap) {
                        Text("Cancel recording")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.minuteTextSecondary)
                            .padding(.bottom, 3)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .stroke(
                                        style: StrokeStyle(
                                            lineWidth: 1,
                                            dash: [2, 2]
                                        )
                                    )
                                    .frame(height: 1)
                                    .foregroundStyle(Color.minuteTextSecondary.opacity(0.9))
                            }
                    }
                    .buttonStyle(.plain)
                    .help("Cancel recording")
                    .accessibilityLabel(Text("Cancel recording"))
                }
            }

            RecordControlButton(
                state: recordState,
                isEnabled: recordEnabled,
                focusBinding: recordFocus,
                action: onRecordTap
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

struct RoundedCornerMask: Shape {
    let topLeft: CGFloat
    let bottomLeft: CGFloat
    let topRight: CGFloat
    let bottomRight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = min(min(topLeft, rect.width / 2), rect.height / 2)
        let tr = min(min(topRight, rect.width / 2), rect.height / 2)
        let bl = min(min(bottomLeft, rect.width / 2), rect.height / 2)
        let br = min(min(bottomRight, rect.width / 2), rect.height / 2)

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct ControlBarIconButton: View {
    let systemName: String
    let label: String
    let isActive: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? Color.white : Color.minuteTextSecondary)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(isActive ? Color.minuteGlow.opacity(0.35) : Color.white.opacity(0.06))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isActive ? 0.4 : 0.16), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .help(label)
        .accessibilityLabel(Text(label))
    }
}

struct RecordControlButton: View {
    let state: RecordButtonState
    let isEnabled: Bool
    let focusBinding: FocusState<Bool>.Binding
    let action: () -> Void

    @State private var isPulsing = false

    private var helpText: String {
        switch state {
        case .ready:
            return "Start recording"
        case .recording:
            return "Stop recording"
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                switch state {
                case .ready:
                    Circle()
                        .fill(Color.red)
                        .frame(width: 58, height: 58)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                case .recording:
                    Circle()
                        .stroke(Color.red, lineWidth: 4)
                        .frame(width: 58, height: 58)

                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 16, height: 16)

                    Circle()
                        .stroke(Color.red.opacity(0.25), lineWidth: 6)
                        .frame(width: 58, height: 58)
                        .scaleEffect(isPulsing ? 1.45 : 0.9)
                        .opacity(isPulsing ? 0 : 0.7)
                }
            }
            .frame(width: 64, height: 64)
        }
        .buttonStyle(.plain)
        .focused(focusBinding)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
        .help(helpText)
        .accessibilityLabel(Text(helpText))
        .onAppear {
            if state == .recording {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: state) { _, newValue in
            if newValue == .recording {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }
}
