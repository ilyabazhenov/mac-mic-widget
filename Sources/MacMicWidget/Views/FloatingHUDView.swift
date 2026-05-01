import SwiftUI

struct FloatingHUDView: View {
    let state: MicrophoneFeedbackState
    @ObservedObject var localizationService: LocalizationService

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.18))
                Image(systemName: state.isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accentColor)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(FloatingHUDPresentationLogic.title(for: state, localizationService: localizationService))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                Text(state.isMuted
                    ? localizationService.string("hud.muted_subtitle")
                    : localizationService.string("hud.active_subtitle"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)

            Text(state.isMuted ? localizationService.string("hud.badge.off") : localizationService.string("hud.badge.on"))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(accentColor)
                .background(
                    Capsule(style: .continuous)
                        .fill(accentColor.opacity(0.16))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var accentColor: Color {
        state.isMuted ? .red : .green
    }
}
