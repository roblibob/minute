import SwiftUI

struct StatusIcon: View {
    enum State {
        case ready
        case attention
        case blocked
    }

    let state: State
    var size: Font

    init(state: State, size: Font = .title2) {
        self.state = state
        self.size = size
    }

    init(isReady: Bool, showsAttention: Bool = false, size: Font = .title2) {
        if isReady {
            self.state = .ready
        } else if showsAttention {
            self.state = .attention
        } else {
            self.state = .blocked
        }
        self.size = size
    }

    var body: some View {
        let iconName: String
        let color: Color
        let label: String

        switch state {
        case .ready:
            iconName = "checkmark.circle.fill"
            color = .green
            label = "Ready"
        case .attention:
            iconName = "arrow.clockwise.circle.fill"
            color = .orange
            label = "Needs attention"
        case .blocked:
            iconName = "xmark.circle.fill"
            color = .red
            label = "Needs attention"
        }

        return Image(systemName: iconName)
            .foregroundStyle(color)
            .font(size)
            .accessibilityLabel(label)
    }
}
